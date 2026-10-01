use std::collections::{HashMap, HashSet, VecDeque};
use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use mtproto_core::auth_key::AuthKey;
use mtproto_core::crypto::{SecureRandom, XorShiftRandom};
use mtproto_core::message::read_auth_key_id;
use mtproto_core::msg_id::msg_id_time;
use mtproto_core::rpc::{INIT_CONNECTION, INPUT_CLIENT_PROXY, INVOKE_WITH_APNS_SECRET, INVOKE_WITH_RECAPTCHA};
use mtproto_core::test_support::server_peer::{self as sp, ServerPeer};
use mtproto_core::test_support::{ServerHandshake, ServerHandshakeBehavior};
use mtproto_core::tl::{Reader, Writer, ids};
use mtproto_core::transport::{
    FrameDecoder, Framing, InputBuffer, ProxySecret, ServerObfuscation, TlsRecordReader, TlsRecordWriter,
    accept_obfuscated_header, encode_frame, server_hello_for_tests, verify_client_hello_for_tests,
};

pub const CALL: u32 = 0x7e57_0001;
pub const CALL_RESULT: u32 = 0x7e57_0002;

pub const TAG_FLOOD_ONCE: u32 = 1001;
pub const TAG_DROP_CONNECTION_ONCE: u32 = 1002;
pub const TAG_LARGE: u32 = 1003;
pub const TAG_NEVER: u32 = 1004;
pub const TAG_SERVER_ERROR_ONCE: u32 = 1005;
pub const TAG_SLOW: u32 = 1006;
pub const TAG_BAD_SALT_ONCE: u32 = 1007;
pub const TAG_KEY_UNKNOWN: u32 = 1008;
pub const TAG_NEW_SESSION: u32 = 1009;
pub const TAG_UNAUTHORIZED: u32 = 1010;
pub const TAG_UPDATE_PUSH: u32 = 1011;
pub const TAG_SIZED: u32 = 1012;
pub const TAG_TRANSPORT_ERROR_ONCE: u32 = 1013;
pub const TAG_BAD_MSG_ONCE: u32 = 1014;
pub const TAG_SERVER_PING: u32 = 1015;
pub const TAG_RESEND_REQ_ONCE: u32 = 1016;
pub const TAG_MSG_COPY: u32 = 1017;
pub const TAG_GARBAGE_SIBLINGS: u32 = 1018;
pub const TAG_GZIP: u32 = 1019;
pub const SERVER_PING_ID: i64 = 0x5e57_9149;
pub const LARGE_SIZE: usize = 1024 * 1024;
pub const SERVER_SALT: i64 = 0x5a17;
const MAX_REMEMBERED_ANSWERS: usize = 16 * 1024;

pub fn call(tag: u32, payload: &[u8]) -> Vec<u8> {
    let mut writer = Writer::new();
    writer.write_u32(CALL);
    writer.write_u32(tag);
    writer.write_bytes(payload);
    writer.into_inner()
}

pub fn sized_call(size: u32) -> Vec<u8> {
    call(TAG_SIZED, &size.to_le_bytes())
}

pub fn transport_error_call(code: i32) -> Vec<u8> {
    call(TAG_TRANSPORT_ERROR_ONCE, &code.to_le_bytes())
}

pub fn bad_msg_call(code: i32, target_container: bool) -> Vec<u8> {
    let mut payload = code.to_le_bytes().to_vec();
    payload.extend_from_slice(&i32::from(target_container).to_le_bytes());
    call(TAG_BAD_MSG_ONCE, &payload)
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum HandshakeFault {
    TransportError(i32),
    Stall,
}

pub fn parse_result(body: &[u8]) -> Option<(u32, Vec<u8>)> {
    let mut reader = Reader::new(body);
    if reader.read_u32().ok()? != CALL_RESULT {
        return None;
    }
    let tag = reader.read_u32().ok()?;
    Some((tag, reader.read_bytes().ok()?.to_vec()))
}

#[derive(Debug, Clone, Default)]
pub struct ServerOptions {
    pub secret: Option<Vec<u8>>,
    pub socks5: bool,
    pub handshake: ServerHandshakeBehavior,
    pub handshake_faults: Vec<HandshakeFault>,
    pub clock_offset: f64,
    pub validate_msg_id_time: bool,
}

#[derive(Debug, Default)]
pub struct Stats {
    pub connections: usize,
    pub obfuscation_dc_ids: Vec<i16>,
    pub executions: HashMap<u32, usize>,
    pub init_connections: usize,
    pub without_updates: usize,
    pub invoke_after: usize,
    pub state_requests: usize,
    pub pings: usize,
    pub future_salts_requests: usize,
    pub handshakes: usize,
    pub closed_by_client: usize,
    pub client_pongs: usize,
    pub retransmissions: usize,
    pub retransmissions_in_container: usize,
    pub duplicate_msg_ids: usize,
    pub redelivered_answers: usize,
    pub bad_msgs_sent: usize,
    pub session_ids: HashSet<i64>,
    pub transport_errors_sent: usize,
}

struct SessionState {
    peer: ServerPeer,
    received: HashSet<i64>,
    unacked: Vec<(i64, i32, Vec<u8>)>,
    answered_queries: HashMap<i64, i64>,
    answer_ids: HashMap<i64, i64>,
    clock_offset: f64,
    awaiting_retransmission: HashSet<i64>,
}

struct Shared {
    keys: HashMap<u64, AuthKey>,
    sessions: HashMap<i64, SessionState>,
    stats: Stats,
    salt: i64,
    bad_salt_sent: bool,
    handshake_faults: VecDeque<HandshakeFault>,
}

pub struct TestServer {
    pub address: SocketAddr,
    shared: Arc<Mutex<Shared>>,
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
    options: ServerOptions,
}

impl TestServer {
    pub fn start(keys: Vec<AuthKey>, options: ServerOptions) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
        listener.set_nonblocking(true).expect("nonblocking");
        let address = listener.local_addr().expect("address");
        let shared = Arc::new(Mutex::new(Shared {
            keys: keys.into_iter().map(|key| (key.id(), key)).collect(),
            sessions: HashMap::new(),
            stats: Stats::default(),
            salt: SERVER_SALT,
            bad_salt_sent: false,
            handshake_faults: options.handshake_faults.iter().copied().collect(),
        }));
        let stop = Arc::new(AtomicBool::new(false));
        let thread = {
            let shared = shared.clone();
            let stop = stop.clone();
            let options = options.clone();
            std::thread::spawn(move || {
                let mut seed = 1u64;
                while !stop.load(Ordering::Relaxed) {
                    match listener.accept() {
                        Ok((stream, _)) => {
                            shared.lock().unwrap().stats.connections += 1;
                            let shared = shared.clone();
                            let stop = stop.clone();
                            let options = options.clone();
                            seed += 1;
                            std::thread::spawn(move || {
                                let _ = serve_connection(stream, shared, stop, options, seed);
                            });
                        }
                        Err(error) if error.kind() == ErrorKind::WouldBlock => {
                            std::thread::sleep(Duration::from_millis(5))
                        }
                        Err(_) => break,
                    }
                }
            })
        };
        Self { address, shared, stop, thread: Some(thread), options }
    }

    pub fn options(&self) -> &ServerOptions {
        &self.options
    }

    pub fn add_key(&self, key: AuthKey) {
        self.shared.lock().unwrap().keys.insert(key.id(), key);
    }

    pub fn remove_key(&self, id: u64) {
        self.shared.lock().unwrap().keys.remove(&id);
    }

    pub fn executions(&self, tag: u32) -> usize {
        self.shared.lock().unwrap().stats.executions.get(&tag).copied().unwrap_or(0)
    }

    pub fn with_stats<R>(&self, f: impl FnOnce(&Stats) -> R) -> R {
        f(&self.shared.lock().unwrap().stats)
    }

    pub fn keys(&self) -> Vec<AuthKey> {
        self.shared.lock().unwrap().keys.values().cloned().collect()
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

fn unix_now() -> f64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs_f64()
}

struct Wire {
    stream: TcpStream,
    obfuscation: Option<ServerObfuscation>,
    tls: bool,
    tls_writer: TlsRecordWriter,
    tls_reader: TlsRecordReader,
    raw: InputBuffer,
    plain: InputBuffer,
    framing: Framing,
    rng: XorShiftRandom,
}

impl Wire {
    fn read_some(&mut self, stop: &AtomicBool) -> std::io::Result<bool> {
        let mut buffer = [0u8; 65536];
        loop {
            if stop.load(Ordering::Relaxed) {
                return Ok(false);
            }
            match self.stream.read(&mut buffer) {
                Ok(0) => return Ok(false),
                Ok(read) => {
                    self.raw.extend(&buffer[..read]);
                    return Ok(true);
                }
                Err(error) if error.kind() == ErrorKind::WouldBlock || error.kind() == ErrorKind::TimedOut => {
                    return Ok(true);
                }
                Err(error) if error.kind() == ErrorKind::Interrupted => continue,
                Err(error) => return Err(error),
            }
        }
    }

    fn decrypt_available(&mut self) -> std::io::Result<()> {
        let Some(obfuscation) = &mut self.obfuscation else {
            return Ok(());
        };
        let mut data = Vec::new();
        if self.tls {
            while self
                .tls_reader
                .read(&mut self.raw, &mut data)
                .map_err(|error| std::io::Error::new(ErrorKind::InvalidData, error.to_string()))?
            {}
        } else {
            data = self.raw.as_slice().to_vec();
            self.raw.consume(data.len());
        }
        obfuscation.decryptor.apply(&mut data);
        self.plain.extend(&data);
        Ok(())
    }

    fn send_frame(&mut self, payload: &[u8]) -> std::io::Result<()> {
        let mut frame = Vec::new();
        encode_frame(self.framing, payload, false, &mut self.rng, &mut frame);
        self.send_raw_frame(frame)
    }

    fn send_raw_frame(&mut self, mut frame: Vec<u8>) -> std::io::Result<()> {
        let obfuscation = self.obfuscation.as_mut().expect("obfuscation");
        obfuscation.encryptor.apply(&mut frame);
        if self.tls {
            let mut out = Vec::new();
            self.tls_writer.write(&frame, &mut out);
            self.stream.write_all(&out)
        } else {
            self.stream.write_all(&frame)
        }
    }

    fn send_quick_ack(&mut self, token: u32) -> std::io::Result<()> {
        let frame = match self.framing {
            Framing::Abridged => (token | 0x8000_0000).to_be_bytes().to_vec(),
            _ => (token | 0x8000_0000).to_le_bytes().to_vec(),
        };
        self.send_raw_frame(frame)
    }
}

fn read_exact_raw(
    stream: &mut TcpStream,
    buffer: &mut InputBuffer,
    count: usize,
    stop: &AtomicBool,
) -> std::io::Result<Vec<u8>> {
    let mut chunk = [0u8; 4096];
    while buffer.len() < count {
        if stop.load(Ordering::Relaxed) {
            return Err(std::io::Error::new(ErrorKind::Interrupted, "stopped"));
        }
        match stream.read(&mut chunk) {
            Ok(0) => return Err(std::io::Error::new(ErrorKind::UnexpectedEof, "eof")),
            Ok(read) => buffer.extend(&chunk[..read]),
            Err(error) if error.kind() == ErrorKind::WouldBlock || error.kind() == ErrorKind::TimedOut => {}
            Err(error) => return Err(error),
        }
    }
    Ok(buffer.take(count))
}

fn socks5_accept(stream: &mut TcpStream, buffer: &mut InputBuffer, stop: &AtomicBool) -> std::io::Result<()> {
    let head = read_exact_raw(stream, buffer, 2, stop)?;
    let methods = read_exact_raw(stream, buffer, head[1] as usize, stop)?;
    if methods.contains(&2) {
        stream.write_all(&[5, 2])?;
        let version = read_exact_raw(stream, buffer, 2, stop)?;
        let _user = read_exact_raw(stream, buffer, version[1] as usize, stop)?;
        let password_len = read_exact_raw(stream, buffer, 1, stop)?;
        let password = read_exact_raw(stream, buffer, password_len[0] as usize, stop)?;
        if password == b"wrong" {
            stream.write_all(&[1, 1])?;
            return Err(std::io::Error::new(ErrorKind::PermissionDenied, "bad credentials"));
        }
        stream.write_all(&[1, 0])?;
    } else {
        stream.write_all(&[5, 0])?;
    }
    let request = read_exact_raw(stream, buffer, 4, stop)?;
    let address_len = match request[3] {
        1 => 4,
        4 => 16,
        3 => read_exact_raw(stream, buffer, 1, stop)?[0] as usize,
        _ => return Err(std::io::Error::new(ErrorKind::InvalidData, "address type")),
    };
    read_exact_raw(stream, buffer, address_len + 2, stop)?;
    stream.write_all(&[5, 0, 0, 1, 127, 0, 0, 1, 0, 80])?;
    Ok(())
}

fn serve_connection(
    mut stream: TcpStream,
    shared: Arc<Mutex<Shared>>,
    stop: Arc<AtomicBool>,
    options: ServerOptions,
    seed: u64,
) -> std::io::Result<()> {
    stream.set_nonblocking(false)?;
    stream.set_read_timeout(Some(Duration::from_millis(20)))?;
    stream.set_nodelay(true)?;
    let mut raw = InputBuffer::new();
    if options.socks5 {
        socks5_accept(&mut stream, &mut raw, &stop)?;
    }
    let secret = options.secret.as_ref().map(|secret| ProxySecret::from_binary(secret, true).expect("secret"));
    let tls = secret.as_ref().is_some_and(ProxySecret::emulate_tls);
    let proxy_key = secret.as_ref().map(ProxySecret::proxy_key);
    let mut rng = XorShiftRandom::new(seed);
    let header: [u8; 64];
    let mut tls_reader = TlsRecordReader::new();
    if tls {
        let record_header = read_exact_raw(&mut stream, &mut raw, 5, &stop)?;
        if record_header[0] != 0x16 {
            return Ok(());
        }
        let record_length = ((record_header[3] as usize) << 8) | record_header[4] as usize;
        let mut hello = record_header;
        hello.extend(read_exact_raw(&mut stream, &mut raw, record_length, &stop)?);
        if verify_client_hello_for_tests(&hello, proxy_key.as_ref().unwrap()).is_none() {
            return Ok(());
        }
        let response = server_hello_for_tests(&hello, proxy_key.as_ref().unwrap(), &mut rng);
        stream.write_all(&response)?;
        let prefix = read_exact_raw(&mut stream, &mut raw, 6, &stop)?;
        assert_eq!(prefix, b"\x14\x03\x03\x00\x01\x01");
        let mut collected = Vec::new();
        while collected.len() < 64 {
            if !tls_reader
                .read(&mut raw, &mut collected)
                .map_err(|error| std::io::Error::new(ErrorKind::InvalidData, error.to_string()))?
            {
                let mut chunk = [0u8; 4096];
                match stream.read(&mut chunk) {
                    Ok(0) => return Ok(()),
                    Ok(read) => raw.extend(&chunk[..read]),
                    Err(error) if error.kind() == ErrorKind::WouldBlock || error.kind() == ErrorKind::TimedOut => {}
                    Err(error) => return Err(error),
                }
            }
        }
        header = collected[..64].try_into().unwrap();
        let rest = collected[64..].to_vec();
        let mut prefixed = InputBuffer::new();
        let mut obfuscation = accept_obfuscated_header(&header, proxy_key.as_ref()).expect("valid header");
        let mut rest = rest;
        obfuscation.decryptor.apply(&mut rest);
        prefixed.extend(&rest);
        let framing = obfuscation.framing;
        let wire = Wire {
            stream,
            obfuscation: Some(obfuscation),
            tls: true,
            tls_writer: {
                let mut writer = TlsRecordWriter::new();
                let mut sink = Vec::new();
                writer.write(&[], &mut sink);
                writer
            },
            tls_reader,
            raw,
            plain: prefixed,
            framing,
            rng,
        };
        return serve_frames(wire, shared, stop, options);
    }
    let head = read_exact_raw(&mut stream, &mut raw, 64, &stop)?;
    header = head.try_into().unwrap();
    let Some(obfuscation) = accept_obfuscated_header(&header, proxy_key.as_ref()) else {
        return Ok(());
    };
    shared.lock().unwrap().stats.obfuscation_dc_ids.push(obfuscation.dc_id);
    let framing = obfuscation.framing;
    let mut wire = Wire {
        stream,
        obfuscation: Some(obfuscation),
        tls: false,
        tls_writer: TlsRecordWriter::new(),
        tls_reader,
        raw,
        plain: InputBuffer::new(),
        framing,
        rng,
    };
    wire.decrypt_available()?;
    serve_frames(wire, shared, stop, options)
}

struct Delayed {
    at: Instant,
    session_id: i64,
    body: Vec<u8>,
}

fn server_now(offset: f64) -> f64 {
    unix_now() + offset
}

fn serve_frames(
    mut wire: Wire,
    shared: Arc<Mutex<Shared>>,
    stop: Arc<AtomicBool>,
    options: ServerOptions,
) -> std::io::Result<()> {
    let decoder = FrameDecoder::new(wire.framing);
    let mut handshake: Option<ServerHandshake> = None;
    let mut handshake_stalled = false;
    let mut delayed: Vec<Delayed> = Vec::new();
    let mut resent_for: HashSet<i64> = HashSet::new();
    loop {
        if stop.load(Ordering::Relaxed) {
            return Ok(());
        }
        let now = Instant::now();
        let (due, later): (Vec<Delayed>, Vec<Delayed>) = delayed.drain(..).partition(|item| item.at <= now);
        delayed = later;
        for item in due {
            let packet = {
                let mut guard = shared.lock().unwrap();
                let Some(session) = guard.sessions.get_mut(&item.session_id) else {
                    continue;
                };
                seal_tracked(session, &item.body, true)
            };
            wire.send_frame(&packet)?;
        }

        let (packet, quick_ack) = match decoder.decode_client_frame(&mut wire.plain) {
            Ok(Some(frame)) => frame,
            Ok(None) => {
                if !wire.read_some(&stop)? {
                    shared.lock().unwrap().stats.closed_by_client += 1;
                    return Ok(());
                }
                wire.decrypt_available()?;
                continue;
            }
            Err(_) => return Ok(()),
        };
        let Some(auth_key_id) = read_auth_key_id(&packet) else {
            continue;
        };
        if auth_key_id == 0 {
            if handshake_stalled {
                continue;
            }
            let starts_handshake = mtproto_core::message::decode_plain_message(&packet)
                .ok()
                .and_then(|message| message.body.get(..4).map(|head| u32::from_le_bytes(head.try_into().unwrap())))
                == Some(ids::REQ_PQ_MULTI);
            if starts_handshake {
                let fault = shared.lock().unwrap().handshake_faults.pop_front();
                match fault {
                    Some(HandshakeFault::TransportError(code)) => {
                        shared.lock().unwrap().stats.transport_errors_sent += 1;
                        wire.send_frame(&code.to_le_bytes())?;
                        let _ = wire.stream.shutdown(Shutdown::Both);
                        return Ok(());
                    }
                    Some(HandshakeFault::Stall) => {
                        handshake_stalled = true;
                        continue;
                    }
                    None => {}
                }
            }
            let reply = handshake
                .get_or_insert_with(|| ServerHandshake::new(options.handshake.clone()))
                .handle(&packet, &mut wire.rng);
            if let Some(reply) = reply {
                wire.send_frame(&reply)?;
            }
            if let Some(outcome) = handshake.as_ref().and_then(|h| h.outcome.clone()) {
                let mut guard = shared.lock().unwrap();
                guard.stats.handshakes += 1;
                guard.keys.insert(outcome.auth_key.id(), outcome.auth_key.clone());
                handshake = None;
            }
            continue;
        }
        let key = shared.lock().unwrap().keys.get(&auth_key_id).cloned();
        let Some(key) = key else {
            wire.send_frame(&(-404i32).to_le_bytes())?;
            let _ = wire.stream.shutdown(Shutdown::Both);
            return Ok(());
        };
        let plaintext = decrypted_plaintext(&key, &packet);
        if quick_ack {
            let hash = mtproto_core::crypto::sha256_parts(&[&key.bytes()[88..120], &plaintext]);
            wire.send_quick_ack(u32::from_le_bytes(hash[..4].try_into().unwrap()) & 0x7fff_ffff)?;
        }
        let decoded = ServerPeer::new(key.clone(), unix_now()).decode(&packet);
        let session_id = decoded.header.session_id;
        let mut outgoing: Vec<(Vec<u8>, bool)> = Vec::new();
        let mut close_after = false;
        let mut transport_error: Option<i32> = None;
        let mut resend: Vec<(i64, i32, Vec<u8>)> = Vec::new();
        {
            let mut guard = shared.lock().unwrap();
            let shared_ref = &mut *guard;
            let salt = shared_ref.salt;
            let session = shared_ref.sessions.entry(session_id).or_insert_with(|| {
                let mut peer = ServerPeer::new(key.clone(), server_now(options.clock_offset));
                peer.session_id = session_id;
                peer.salt = salt;
                SessionState {
                    peer,
                    received: HashSet::new(),
                    unacked: Vec::new(),
                    answered_queries: HashMap::new(),
                    answer_ids: HashMap::new(),
                    clock_offset: options.clock_offset,
                    awaiting_retransmission: HashSet::new(),
                }
            });
            session.peer.server_time = server_now(session.clock_offset);
            session.peer.salt = salt;
            if resent_for.insert(session_id) {
                resend = session.unacked.clone();
            }
            let stats = &mut shared_ref.stats;
            stats.session_ids.insert(session_id);
            let message_time = msg_id_time(decoded.header.msg_id);
            let server_time = server_now(session.clock_offset);
            let time_error = if !options.validate_msg_id_time {
                None
            } else if message_time < server_time - 300.0 {
                Some(16)
            } else if message_time > server_time + 30.0 {
                Some(17)
            } else {
                None
            };
            if let Some(code) = time_error {
                stats.bad_msgs_sent += 1;
                outgoing.push((sp::bad_msg_notification(decoded.header.msg_id, decoded.header.seq_no, code), false));
            } else if decoded.header.salt != salt {
                outgoing.push((sp::bad_server_salt(decoded.header.msg_id, decoded.header.seq_no, salt), false));
            } else {
                for message in &decoded.messages {
                    if !session.received.insert(message.msg_id) {
                        stats.duplicate_msg_ids += 1;
                        let cached = session
                            .answer_ids
                            .get(&message.msg_id)
                            .and_then(|answer_id| session.unacked.iter().find(|(id, _, _)| id == answer_id).cloned());
                        if let Some(answer) = cached
                            && !resend.iter().any(|(id, _, _)| *id == answer.0)
                        {
                            stats.redelivered_answers += 1;
                            resend.push(answer);
                        }
                        continue;
                    }
                    if session.awaiting_retransmission.remove(&message.msg_id) {
                        stats.retransmissions += 1;
                        if message.container_id.is_some() {
                            stats.retransmissions_in_container += 1;
                        }
                    }
                    match message.constructor() {
                        ids::PONG => {
                            let ping_id = i64::from_le_bytes(message.body[12..20].try_into().unwrap());
                            if ping_id == SERVER_PING_ID {
                                stats.client_pongs += 1;
                            }
                        }
                        ids::PING | ids::PING_DELAY_DISCONNECT => {
                            stats.pings += 1;
                            let ping_id = i64::from_le_bytes(message.body[4..12].try_into().unwrap());
                            outgoing.push((sp::pong(message.msg_id, ping_id), true));
                        }
                        ids::GET_FUTURE_SALTS => {
                            stats.future_salts_requests += 1;
                            outgoing.push((future_salts_reply(message.msg_id, salt, session.clock_offset), true));
                        }
                        ids::MSGS_ACK => {
                            let acked = sp::read_vector_after_constructor(&message.body);
                            session.unacked.retain(|(id, _, _)| !acked.contains(id));
                        }
                        ids::MSGS_STATE_REQ => {
                            stats.state_requests += 1;
                            let asked = sp::read_vector_after_constructor(&message.body);
                            let info: Vec<u8> =
                                asked.iter().map(|id| if session.received.contains(id) { 4 } else { 2 }).collect();
                            outgoing.push((sp::msgs_state_info(message.msg_id, &info), true));
                        }
                        ids::MSG_RESEND_REQ | ids::MSG_RESEND_ANS_REQ => {
                            let asked = sp::read_vector_after_constructor(&message.body);
                            for entry in &session.unacked {
                                if asked.contains(&entry.0) {
                                    resend.push(entry.clone());
                                }
                            }
                        }
                        ids::RPC_DROP_ANSWER => {}
                        _ => {
                            let (call, flags) = unwrap_wrappers(&message.body);
                            stats.init_connections += usize::from(flags.init_connection);
                            stats.without_updates += usize::from(flags.without_updates);
                            stats.invoke_after += usize::from(flags.invoke_after);
                            let Some((tag, payload)) = call else {
                                continue;
                            };
                            if tag == TAG_BAD_SALT_ONCE && !shared_ref.bad_salt_sent {
                                shared_ref.bad_salt_sent = true;
                                shared_ref.salt = salt.wrapping_add(1);
                                session.received.remove(&message.msg_id);
                                outgoing.push((
                                    sp::bad_server_salt(message.msg_id, message.seq_no, shared_ref.salt),
                                    false,
                                ));
                                continue;
                            }
                            let count = {
                                let entry = stats.executions.entry(tag).or_insert(0);
                                *entry += 1;
                                *entry
                            };
                            let reply = sp::rpc_result(message.msg_id, &result_body(tag, &payload));
                            let payload_word = |index: usize| {
                                payload
                                    .get(index * 4..index * 4 + 4)
                                    .map(|bytes| i32::from_le_bytes(bytes.try_into().unwrap()))
                                    .unwrap_or(0)
                            };
                            match tag {
                                TAG_TRANSPORT_ERROR_ONCE if count == 1 => {
                                    session.received.remove(&message.msg_id);
                                    stats.transport_errors_sent += 1;
                                    transport_error = Some(payload_word(0));
                                }
                                TAG_BAD_MSG_ONCE if count == 1 => {
                                    let target = if payload_word(1) == 1 {
                                        message.container_id.unwrap_or(message.msg_id)
                                    } else {
                                        message.msg_id
                                    };
                                    session.received.remove(&message.msg_id);
                                    stats.bad_msgs_sent += 1;
                                    outgoing.push((
                                        sp::bad_msg_notification(target, message.seq_no, payload_word(0)),
                                        false,
                                    ));
                                }
                                TAG_SERVER_PING => {
                                    outgoing.push((sp::server_ping(SERVER_PING_ID), false));
                                    outgoing.push((reply, true));
                                }
                                TAG_RESEND_REQ_ONCE if count == 1 => {
                                    session.received.remove(&message.msg_id);
                                    session.awaiting_retransmission.insert(message.msg_id);
                                    outgoing.push((sp::msg_resend_req(&[message.msg_id]), false));
                                }
                                TAG_MSG_COPY => {
                                    session.peer.server_time = server_now(session.clock_offset);
                                    let inner = session.peer.next_msg_id(true);
                                    outgoing.push((sp::msg_copy(inner, 1, &reply), false));
                                }
                                TAG_GARBAGE_SIBLINGS => {
                                    session.peer.server_time = server_now(session.clock_offset);
                                    let ids_: Vec<i64> = (0..4).map(|_| session.peer.next_msg_id(false)).collect();
                                    let truncated = sp::bad_msg_notification(message.msg_id, 1, 16)[..12].to_vec();
                                    let mut http_wait = Writer::new();
                                    mtproto_core::tl::mtproto::write_http_wait(&mut http_wait, 0, 0, 0);
                                    let body = sp::container(&[
                                        (ids_[0], 1, sp::update(0xdead_beef, &[0; 8])),
                                        (ids_[1], 1, truncated),
                                        (ids_[2], 0, http_wait.into_inner()),
                                        (ids_[3], 1, reply),
                                    ]);
                                    outgoing.push((body, false));
                                }
                                TAG_GZIP => {
                                    session.peer.server_time = server_now(session.clock_offset);
                                    let first = session.peer.next_msg_id(false);
                                    let second = session.peer.next_msg_id(true);
                                    let body = sp::container(&[
                                        (first, 1, sp::gzip_packed(&sp::update(0x74ae4240, &tag.to_le_bytes()))),
                                        (
                                            second,
                                            1,
                                            sp::rpc_result_gzipped(message.msg_id, &result_body(tag, &payload)),
                                        ),
                                    ]);
                                    outgoing.push((sp::gzip_packed(&body), false));
                                }
                                TAG_KEY_UNKNOWN => transport_error = Some(-404),
                                TAG_FLOOD_ONCE if count == 1 => {
                                    outgoing.push((sp::rpc_error(message.msg_id, 420, "FLOOD_WAIT_1"), true))
                                }
                                TAG_SERVER_ERROR_ONCE if count == 1 => {
                                    outgoing.push((sp::rpc_error(message.msg_id, 500, "INTERNAL_SERVER_ERROR"), true))
                                }
                                TAG_UNAUTHORIZED => {
                                    outgoing.push((sp::rpc_error(message.msg_id, 401, "AUTH_KEY_UNREGISTERED"), true))
                                }
                                TAG_DROP_CONNECTION_ONCE if count == 1 => {
                                    session.peer.server_time = server_now(session.clock_offset);
                                    let msg_id = session.peer.next_msg_id(true);
                                    session.unacked.push((msg_id, 1, reply));
                                    close_after = true;
                                }
                                TAG_NEVER => {}
                                TAG_SLOW => delayed.push(Delayed {
                                    at: Instant::now() + Duration::from_millis(300),
                                    session_id,
                                    body: reply,
                                }),
                                TAG_LARGE => {
                                    let large = vec![0x42u8; LARGE_SIZE];
                                    outgoing.push((sp::rpc_result(message.msg_id, &result_body(tag, &large)), true));
                                }
                                TAG_NEW_SESSION if count == 1 => {
                                    outgoing.push((sp::new_session_created(message.msg_id + 4, 77, salt), true));
                                    outgoing.push((reply, true));
                                }
                                TAG_SIZED => {
                                    let size = payload
                                        .get(..4)
                                        .map(|bytes| u32::from_le_bytes(bytes.try_into().unwrap()) as usize)
                                        .unwrap_or(0)
                                        .min(4 * 1024 * 1024);
                                    let data = vec![(count & 0xff) as u8; size];
                                    outgoing.push((sp::rpc_result(message.msg_id, &result_body(tag, &data)), true));
                                }
                                TAG_UPDATE_PUSH => {
                                    outgoing.push((sp::update(0x74ae4240, &tag.to_le_bytes()), true));
                                    outgoing.push((reply, true));
                                }
                                _ => outgoing.push((reply, true)),
                            }
                            session.answered_queries.insert(message.msg_id, 0);
                        }
                    }
                }
            }
        }
        if let Some(code) = transport_error {
            wire.send_frame(&code.to_le_bytes())?;
            let _ = wire.stream.shutdown(Shutdown::Both);
            return Ok(());
        }
        let packets: Vec<Vec<u8>> = {
            let mut guard = shared.lock().unwrap();
            let session = guard.sessions.get_mut(&session_id).unwrap();
            let mut packets: Vec<Vec<u8>> =
                resend.iter().map(|(msg_id, seq, body)| session.peer.seal(*msg_id, *seq, body)).collect();
            for (body, content) in &outgoing {
                packets.push(seal_tracked(session, body, *content));
            }
            packets
        };
        for packet in packets {
            wire.send_frame(&packet)?;
        }
        if close_after {
            let _ = wire.stream.shutdown(Shutdown::Both);
            return Ok(());
        }
    }
}

fn seal_tracked(session: &mut SessionState, body: &[u8], content: bool) -> Vec<u8> {
    session.peer.server_time = server_now(session.clock_offset);
    let msg_id = session.peer.next_msg_id(true);
    let seq = if content { 1 } else { 0 };
    if body.len() >= 12 && u32::from_le_bytes(body[..4].try_into().unwrap()) == ids::RPC_RESULT {
        session.unacked.push((msg_id, seq, body.to_vec()));
        let req_msg_id = i64::from_le_bytes(body[4..12].try_into().unwrap());
        session.answer_ids.insert(req_msg_id, msg_id);
        if session.answer_ids.len() > MAX_REMEMBERED_ANSWERS {
            let unacked: HashSet<i64> = session.unacked.iter().map(|(id, _, _)| *id).collect();
            session.answer_ids.retain(|_, answer_id| unacked.contains(answer_id));
        }
    }
    session.peer.seal(msg_id, seq, body)
}

fn decrypted_plaintext(key: &AuthKey, packet: &[u8]) -> Vec<u8> {
    let msg_key: [u8; 16] = packet[8..24].try_into().unwrap();
    let material = mtproto_core::crypto::message_key_v2(key.bytes(), &msg_key, mtproto_core::crypto::Side::Client);
    let mut plain = packet[24..].to_vec();
    mtproto_core::crypto::aes_ige_decrypt(&material.key, &material.iv, &mut plain).unwrap();
    plain
}

fn result_body(tag: u32, payload: &[u8]) -> Vec<u8> {
    let mut writer = Writer::new();
    writer.write_u32(CALL_RESULT);
    writer.write_u32(tag);
    writer.write_bytes(payload);
    writer.into_inner()
}

fn future_salts_reply(req_msg_id: i64, salt: i64, clock_offset: f64) -> Vec<u8> {
    let now = server_now(clock_offset) as i32;
    sp::future_salts(req_msg_id, now, &[(now - 60, now + 3600, salt), (now + 3600, now + 7200, salt)])
}

#[derive(Default)]
struct WrapperFlags {
    init_connection: bool,
    without_updates: bool,
    invoke_after: bool,
}

fn unwrap_wrappers(body: &[u8]) -> (Option<(u32, Vec<u8>)>, WrapperFlags) {
    let mut flags = WrapperFlags::default();
    let mut reader = Reader::new(body);
    loop {
        let Ok(constructor) = reader.read_u32() else {
            return (None, flags);
        };
        match constructor {
            ids::INVOKE_AFTER_MSG => {
                flags.invoke_after = true;
                if reader.read_i64().is_err() {
                    return (None, flags);
                }
            }
            ids::INVOKE_WITHOUT_UPDATES => flags.without_updates = true,
            ids::INVOKE_WITH_LAYER => {
                let _ = reader.read_i32();
                if reader.read_u32().ok() != Some(INIT_CONNECTION) {
                    return (None, flags);
                }
                flags.init_connection = true;
                let flag_bits = reader.read_i32().unwrap_or(0);
                let _ = reader.read_i32();
                for _ in 0..6 {
                    let _ = reader.read_bytes();
                }
                if flag_bits & 1 != 0 {
                    let _ = reader.read_u32().ok().filter(|c| *c == INPUT_CLIENT_PROXY);
                    let _ = reader.read_bytes();
                    let _ = reader.read_i32();
                }
                if flag_bits & 2 != 0 {
                    return (None, flags);
                }
            }
            INVOKE_WITH_APNS_SECRET => {
                let _ = reader.read_bytes();
                let _ = reader.read_bytes();
            }
            INVOKE_WITH_RECAPTCHA => {
                let _ = reader.read_bytes();
            }
            CALL => {
                let tag = reader.read_u32().unwrap_or(0);
                let payload = reader.read_bytes().map(<[u8]>::to_vec).unwrap_or_default();
                return (Some((tag, payload)), flags);
            }
            _ => return (None, flags),
        }
    }
}

pub fn random_key(seed: u64) -> AuthKey {
    let mut rng = XorShiftRandom::new(seed);
    AuthKey::new(rng.array())
}
