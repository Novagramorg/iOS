use std::collections::VecDeque;
use std::net::SocketAddr;
use std::sync::Arc;

use mio::{Registry, Token};
use mtproto_core::crypto::{OsRandom, SecureRandom};
use mtproto_core::handshake::{Handshake, HandshakeConfig, HandshakeStep};
use mtproto_core::rpc::{ApiEnvironment, RequestId, RpcClient, RpcEvent, RpcRequest, SessionRole, Verification};
use mtproto_core::session::{Now, ServerSalt, Session, SessionConfig, SessionError};
use mtproto_core::transport::{
    reconnect_delay, transport_flood_delay, Incoming, Socks5Auth, Socks5Target, TransportConfig, TransportErrorKind,
};

use crate::connection::{ChunkStatus, Connection, ConnectionError};
use crate::resolver::parse_literal;
use crate::types::{
    AuthKeyMaterial, ConnectionState, DcAddress, EngineCallbacks, EngineConfig, EngineEvent, LogLevel, ProxyConfig,
    SessionHandle, SessionSetup,
};

const PROGRESS_THRESHOLD: usize = 4096;
const PROGRESS_HEAD: usize = 128;
const HANDSHAKE_TIMEOUT: f64 = 10.0;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CloseReason {
    ServerRejected,
    TransportFlood,
    HandshakeFailed,
}

pub enum Resolution {
    Resolved(Vec<SocketAddr>),
    Pending,
}

pub trait Resolve {
    fn resolve(&mut self, session: SessionHandle, host: &str, port: u16) -> Resolution;
}

struct ProgressTracking {
    frame_length: usize,
    target: Option<RequestId>,
    last_reported: usize,
}

pub struct SessionRuntime {
    pub handle: SessionHandle,
    setup: SessionSetup,
    rpc: Option<RpcClient>,
    queued: VecDeque<RpcRequest>,
    pending_plain: VecDeque<Vec<u8>>,
    handshake: Option<Handshake>,
    connection: Option<Connection>,
    token: Token,
    next_attempt_at: f64,
    failures: u32,
    address_cursor: usize,
    last_activity_at: f64,
    timeout_fired: bool,
    reported_key_required: bool,
    network_available: bool,
    last_state: Option<(ConnectionState, Option<String>)>,
    progress: Option<ProgressTracking>,
    reported_in: u64,
    reported_out: u64,
    last_usage_report: f64,
    resolved: Option<(String, Vec<SocketAddr>)>,
    closed: bool,
    close_reason: Option<CloseReason>,
    transport_floods: u32,
    handshake_started_at: Option<f64>,
    jitter_state: u64,
}

impl SessionRuntime {
    pub fn new(handle: SessionHandle, setup: SessionSetup, token: Token, now: Now, rng: &mut OsRandom) -> Self {
        let mut runtime = Self {
            handle,
            rpc: None,
            queued: VecDeque::new(),
            pending_plain: VecDeque::new(),
            handshake: None,
            connection: None,
            token,
            next_attempt_at: now.mono,
            failures: 0,
            address_cursor: 0,
            last_activity_at: now.mono,
            timeout_fired: false,
            reported_key_required: false,
            network_available: true,
            last_state: None,
            progress: None,
            reported_in: 0,
            reported_out: 0,
            last_usage_report: now.mono,
            resolved: None,
            closed: false,
            close_reason: None,
            transport_floods: 0,
            handshake_started_at: None,
            jitter_state: rng.next_u64() | 1,
            setup,
        };
        if let Some(material) = runtime.setup.auth_key.take() {
            runtime.install_key(material, now, rng);
        }
        runtime
    }

    pub fn token(&self) -> Token {
        self.token
    }

    fn session_config(&self) -> SessionConfig {
        SessionConfig {
            is_main: self.setup.role == SessionRole::Main,
            ..SessionConfig::default()
        }
    }

    fn install_key(&mut self, material: AuthKeyMaterial, now: Now, rng: &mut OsRandom) {
        match &mut self.rpc {
            Some(rpc) => {
                if rpc.session().auth_key_id() != material.key.id() {
                    rpc.session_mut().replace_auth_key(material.key, &material.salts, now);
                    rpc.reset_session(now, rng);
                    rpc.set_stored_init_hash(material.init_hash);
                } else {
                    rpc.session_mut().merge_salts(&material.salts, now);
                }
            }
            None => {
                let mut session = Session::new(
                    self.session_config(),
                    material.key,
                    &material.salts,
                    self.setup.time_difference,
                    now,
                    rng,
                );
                session.set_online(self.setup.online, now);
                let mut rpc = RpcClient::new(session, self.setup.role, self.setup.environment.clone(), material.init_hash);
                if self.connection.as_ref().is_some_and(Connection::is_established) && self.handshake.is_none() {
                    rpc.connection_opened(now);
                }
                for request in self.queued.drain(..) {
                    rpc.send(request, now);
                }
                self.rpc = Some(rpc);
            }
        }
        self.reported_key_required = false;
    }

    pub fn has_work(&self) -> bool {
        self.rpc.as_ref().is_some_and(|rpc| rpc.request_count() > 0) || !self.queued.is_empty()
    }

    fn wants_connection(&self, now: Now) -> bool {
        if self.setup.paused || self.closed || !self.network_available || self.setup.addresses.is_empty() {
            return false;
        }
        if self.rpc.is_none() {
            return self.setup.key_generation.is_some();
        }
        if self.setup.keep_connected || self.has_work() {
            return true;
        }
        match (self.setup.idle_disconnect_after, &self.connection) {
            (Some(idle), Some(_)) => now.mono - self.last_activity_at < idle,
            _ => false,
        }
    }

    pub fn send(&mut self, request: RpcRequest, now: Now) {
        self.last_activity_at = now.mono;
        match &mut self.rpc {
            Some(rpc) => rpc.send(request, now),
            None => self.queued.push_back(request),
        }
    }

    pub fn cancel(&mut self, id: RequestId, now: Now, registry: &Registry, callbacks: &Arc<dyn EngineCallbacks>) {
        if let Some(position) = self.queued.iter().position(|request| request.id == id) {
            self.queued.remove(position);
            return;
        }
        if let Some(rpc) = &mut self.rpc {
            rpc.cancel(id, now);
        }
        self.pump_rpc_events(now, registry, callbacks);
    }

    pub fn set_paused(&mut self, paused: bool, now: Now, registry: &Registry) {
        if self.setup.paused == paused {
            return;
        }
        self.setup.paused = paused;
        if paused {
            self.close_connection(registry, now, false);
        } else {
            self.next_attempt_at = now.mono;
            self.failures = 0;
        }
    }

    pub fn set_online(&mut self, online: bool, now: Now) {
        self.setup.online = online;
        if let Some(rpc) = &mut self.rpc {
            rpc.session_mut().set_online(online, now);
        }
    }

    pub fn set_auth_key(&mut self, material: Option<AuthKeyMaterial>, now: Now, registry: &Registry, rng: &mut OsRandom) {
        match material {
            Some(material) => {
                let changed = self.rpc.as_ref().is_some_and(|rpc| rpc.session().auth_key_id() != material.key.id());
                self.install_key(material, now, rng);
                if changed {
                    self.close_connection(registry, now, false);
                    self.next_attempt_at = now.mono;
                }
            }
            None => {
                if let Some(rpc) = self.rpc.take() {
                    let _ = rpc;
                }
                self.close_connection(registry, now, false);
            }
        }
    }

    pub fn set_addresses(&mut self, addresses: Vec<DcAddress>, now: Now, registry: &Registry) {
        if self.setup.addresses != addresses {
            self.setup.addresses = addresses;
            self.address_cursor = 0;
            self.resolved = None;
            self.close_connection(registry, now, false);
            self.next_attempt_at = now.mono;
            self.failures = 0;
        }
    }

    pub fn set_proxy(&mut self, proxy: Option<ProxyConfig>, now: Now, registry: &Registry) {
        if self.setup.proxy != proxy {
            self.setup.proxy = proxy;
            self.resolved = None;
            self.close_connection(registry, now, false);
            self.next_attempt_at = now.mono;
            self.failures = 0;
        }
    }

    pub fn update_environment(&mut self, environment: ApiEnvironment, noop: Option<RpcRequest>, now: Now) {
        self.setup.environment = Some(environment.clone());
        if let Some(rpc) = &mut self.rpc {
            rpc.update_environment(environment, noop, now);
        }
    }

    pub fn set_auth_token_ready(&mut self, ready: bool, now: Now) {
        if let Some(rpc) = &mut self.rpc {
            rpc.set_auth_token_ready(ready, now);
        }
    }

    pub fn resolve_verification(&mut self, id: RequestId, verification: Verification, now: Now) {
        if let Some(rpc) = &mut self.rpc {
            rpc.resolve_verification(id, verification, now);
        }
    }

    pub fn decide_retry(&mut self, id: RequestId, retry: bool, now: Now) {
        if let Some(rpc) = &mut self.rpc {
            rpc.decide_retry(id, retry, now);
        }
    }

    pub fn fail_request(&mut self, id: RequestId, code: i32, message: &str, now: Now) {
        if let Some(rpc) = &mut self.rpc {
            rpc.fail_request(id, code, message, now);
        }
    }

    pub fn invalidate_initialization(&mut self) {
        if let Some(rpc) = &mut self.rpc {
            rpc.invalidate_initialization();
        }
    }

    pub fn set_time_difference(&mut self, difference: f64) {
        self.setup.time_difference = difference;
        if let Some(rpc) = &mut self.rpc {
            rpc.session_mut().set_time_difference(difference);
        }
    }

    pub fn set_network_available(&mut self, available: bool, now: Now, registry: &Registry) {
        if self.network_available != available {
            self.network_available = available;
            if !available {
                self.close_connection(registry, now, false);
            } else {
                self.failures = 0;
                self.next_attempt_at = now.mono;
            }
        }
    }

    pub fn reset_connection(&mut self, now: Now, registry: &Registry) {
        self.close_connection(registry, now, false);
        self.failures = 0;
        self.next_attempt_at = now.mono;
    }

    pub fn shutdown(&mut self, registry: &Registry, now: Now) {
        self.closed = true;
        self.close_connection(registry, now, false);
    }

    fn next_jitter(&mut self) -> u32 {
        self.jitter_state ^= self.jitter_state << 13;
        self.jitter_state ^= self.jitter_state >> 7;
        self.jitter_state ^= self.jitter_state << 17;
        (self.jitter_state >> 32) as u32
    }

    fn close_connection(&mut self, registry: &Registry, now: Now, failed: bool) {
        self.close_reason = None;
        if let Some(mut connection) = self.connection.take() {
            self.account_usage(&connection);
            connection.deregister(registry);
            let index = connection.address_index;
            if failed {
                self.failures += 1;
                let jitter = self.next_jitter();
                let delay = reconnect_delay(self.failures, jitter);
                self.next_attempt_at = self.next_attempt_at.max(now.mono + delay);
                self.address_cursor = index + 1;
            }
            if let Some(rpc) = &mut self.rpc {
                rpc.connection_closed(now);
            }
            self.handshake = None;
            self.handshake_started_at = None;
            self.pending_plain.clear();
            self.progress = None;
        }
    }

    fn account_usage(&mut self, connection: &Connection) {
        self.reported_in += connection.bytes_in;
        self.reported_out += connection.bytes_out;
    }

    fn pick_address(&mut self, resolver: &mut dyn Resolve) -> Option<(usize, SocketAddr, DcAddress)> {
        let count = self.setup.addresses.len();
        if count == 0 {
            return None;
        }
        let index = self.address_cursor % count;
        let address = self.setup.addresses[index].clone();
        let (host, port) = match &self.setup.proxy {
            Some(ProxyConfig::Socks5 { host, port, .. }) | Some(ProxyConfig::MtProxy { host, port, .. }) => (host.clone(), *port),
            None => (address.host.clone(), address.port),
        };
        let socket_address = match parse_literal(&host, port) {
            Some(address) => address,
            None => {
                let key = format!("{host}:{port}");
                match &self.resolved {
                    Some((cached, addresses)) if *cached == key && !addresses.is_empty() => {
                        addresses[self.failures as usize % addresses.len()]
                    }
                    _ => match resolver.resolve(self.handle, &host, port) {
                        Resolution::Resolved(addresses) if !addresses.is_empty() => {
                            let first = addresses[0];
                            self.resolved = Some((key, addresses));
                            first
                        }
                        Resolution::Resolved(_) => return None,
                        Resolution::Pending => return None,
                    },
                }
            }
        };
        Some((index, socket_address, address))
    }

    pub fn on_resolved(&mut self, host: String, port: u16, addresses: Vec<SocketAddr>, now: Now) {
        self.resolved = Some((format!("{host}:{port}"), addresses));
        self.next_attempt_at = now.mono;
    }

    fn start_connection(&mut self, registry: &Registry, now: Now, resolver: &mut dyn Resolve, config: &EngineConfig, rng: &mut OsRandom) {
        let Some((index, socket_address, address)) = self.pick_address(resolver) else {
            return;
        };
        let socks = match &self.setup.proxy {
            Some(ProxyConfig::Socks5 { username, password, .. }) => {
                let target = match parse_literal(&address.host, address.port) {
                    Some(SocketAddr::V4(v4)) => Socks5Target::Ipv4(v4.ip().octets(), address.port),
                    Some(SocketAddr::V6(v6)) => Socks5Target::Ipv6(v6.ip().octets(), address.port),
                    None => Socks5Target::Domain(address.host.clone(), address.port),
                };
                let auth = match (username, password) {
                    (Some(username), Some(password)) if !username.is_empty() => Some(Socks5Auth {
                        username: username.clone(),
                        password: password.clone(),
                    }),
                    _ => None,
                };
                Some((target, auth))
            }
            _ => None,
        };
        let transport = TransportConfig {
            framing: self.setup.framing,
            dc_id: self.setup.obfuscation_dc_id,
            secret: self.setup.proxy_secret(&address),
            unix_time: (now.unix + self.time_difference()) as i32,
        };
        match Connection::connect(registry, self.token, socket_address, &transport, socks, index, now.mono, rng) {
            Ok(connection) => {
                self.connection = Some(connection);
                let _ = config;
            }
            Err(_) => {
                self.failures += 1;
                self.address_cursor = index + 1;
                let jitter = self.next_jitter();
                self.next_attempt_at = now.mono + reconnect_delay(self.failures, jitter).max(0.3);
            }
        }
    }

    fn time_difference(&self) -> f64 {
        self.rpc
            .as_ref()
            .map(|rpc| rpc.session().time_difference())
            .unwrap_or(self.setup.time_difference)
    }

    fn on_established(&mut self, now: Now, callbacks: &Arc<dyn EngineCallbacks>, rng: &mut OsRandom) {
        match &mut self.connection {
            Some(connection) => connection.last_read_at = now.mono,
            None => return,
        }
        if self.rpc.is_some() {
            if let Some(rpc) = &mut self.rpc {
                rpc.connection_opened(now);
            }
        } else if let Some(generation) = &self.setup.key_generation {
            let config = HandshakeConfig {
                dc_id: self.setup.datacenter_id,
                temp_key_expires_in: generation.temporary_expires_in,
                public_keys: generation.public_keys.clone(),
            };
            let (handshake, packet) = Handshake::start(config, now.unix + self.setup.time_difference, rng);
            self.handshake = Some(handshake);
            self.handshake_started_at = Some(now.mono);
            let _ = callbacks;
            self.pending_plain.push_back(packet);
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn handle_io(
        &mut self,
        readable: bool,
        writable: bool,
        registry: &Registry,
        scratch: &mut [u8],
        now: Now,
        callbacks: &Arc<dyn EngineCallbacks>,
        rng: &mut OsRandom,
    ) {
        if self.connection.is_none() {
            return;
        }
        let mut failure: Option<ConnectionError> = None;
        if writable {
            let result = self.connection.as_mut().expect("connection").handle_writable(registry, now.mono);
            match result {
                Ok(true) => self.on_established(now, callbacks, rng),
                Ok(false) => {}
                Err(error) => failure = Some(error),
            }
        }
        if readable && failure.is_none() {
            while let Some(connection) = self.connection.as_mut() {
                match connection.read_chunk(registry, scratch, now.mono) {
                    Ok(ChunkStatus::Data { became_ready }) => {
                        if became_ready {
                            self.on_established(now, callbacks, rng);
                        }
                        if let Some(rpc) = &mut self.rpc {
                            rpc.note_bytes_received(now);
                        }
                        if let Err(error) = self.process_incoming(registry, now, callbacks, rng) {
                            failure = Some(error);
                            break;
                        }
                    }
                    Ok(ChunkStatus::WouldBlock) => break,
                    Ok(ChunkStatus::Eof) => {
                        failure = Some(ConnectionError::Closed);
                        break;
                    }
                    Err(error) => {
                        failure = Some(error);
                        break;
                    }
                }
            }
        }
        if failure.is_none() {
            if let Err(error) = self.process_incoming(registry, now, callbacks, rng) {
                failure = Some(error);
            }
        } else if matches!(failure, Some(ConnectionError::Closed) | Some(ConnectionError::Io(_)))
            && let Err(error) = self.process_incoming(registry, now, callbacks, rng) {
                failure = Some(error);
            }
        if let Some(error) = failure {
            if self.connection.is_none() {
                return;
            }
            self.log(callbacks, LogLevel::Info, &format!("connection closed: {error}"));
            let established = self.connection.as_ref().is_some_and(Connection::is_established);
            let reason = self.close_reason.take();
            let reachable = matches!(reason, Some(CloseReason::ServerRejected) | Some(CloseReason::TransportFlood));
            if let Some(connection) = &self.connection {
                callbacks.on_event(
                    self.handle,
                    EngineEvent::AddressResult {
                        index: connection.address_index,
                        success: connection.received_packet || reachable,
                    },
                );
            }
            let received = self.connection_received_packet();
            let failed = match reason {
                Some(CloseReason::ServerRejected) | Some(CloseReason::HandshakeFailed) => true,
                Some(CloseReason::TransportFlood) => false,
                None => !established || !received,
            };
            self.close_connection(registry, now, failed);
        }
    }

    fn connection_received_packet(&self) -> bool {
        self.connection.as_ref().is_some_and(|connection| connection.received_packet)
    }

    fn process_incoming(
        &mut self,
        registry: &Registry,
        now: Now,
        callbacks: &Arc<dyn EngineCallbacks>,
        rng: &mut OsRandom,
    ) -> Result<(), ConnectionError> {
        loop {
            let Some(connection) = &mut self.connection else {
                return Ok(());
            };
            let incoming = connection.next_incoming()?;
            let Some(incoming) = incoming else {
                break;
            };
            self.progress = None;
            match incoming {
                Incoming::Packet(packet) => {
                    if let Some(handshake) = &mut self.handshake {
                        match handshake.on_packet(&packet, now.unix, None, rng) {
                            Ok(HandshakeStep::Send(next)) => self.pending_plain.push_back(next),
                            Ok(HandshakeStep::Done(result)) => {
                                self.handshake = None;
                                self.handshake_started_at = None;
                                self.failures = 0;
                                let expires_at = result.expires_at;
                                let server_time = now.unix + result.time_difference;
                                self.setup.time_difference = result.time_difference;
                                callbacks.on_event(
                                    self.handle,
                                    EngineEvent::AuthKeyCreated {
                                        key: result.auth_key.bytes().to_vec(),
                                        salt: result.server_salt,
                                        time_difference: result.time_difference,
                                        expires_at,
                                    },
                                );
                                let material = AuthKeyMaterial {
                                    key: result.auth_key,
                                    salts: vec![ServerSalt {
                                        salt: result.server_salt,
                                        valid_since: server_time - 1.0,
                                        valid_until: server_time + 600.0,
                                    }],
                                    init_hash: None,
                                };
                                self.install_key(material, now, rng);
                                if let Some(rpc) = &mut self.rpc {
                                    rpc.connection_opened(now);
                                }
                            }
                            Err(error) => {
                                callbacks.on_event(
                                    self.handle,
                                    EngineEvent::AuthKeyCreationFailed {
                                        reason: error.to_string(),
                                    },
                                );
                                self.close_reason = Some(CloseReason::HandshakeFailed);
                                return Err(ConnectionError::Closed);
                            }
                        }
                        continue;
                    }
                    let Some(rpc) = &mut self.rpc else {
                        continue;
                    };
                    match rpc.handle_packet(&packet, now, rng) {
                        Ok(()) => {
                            self.transport_floods = 0;
                            if let Some(connection) = &mut self.connection
                                && !connection.received_packet {
                                    connection.received_packet = true;
                                    self.failures = 0;
                                    callbacks.on_event(
                                        self.handle,
                                        EngineEvent::AddressResult {
                                            index: connection.address_index,
                                            success: true,
                                        },
                                    );
                                }
                            self.timeout_fired = false;
                        }
                        Err(SessionError::ForeignSession) | Err(SessionError::TooOld) | Err(SessionError::EvenServerMsgId(_)) => {}
                        Err(error) => {
                            self.log(callbacks, LogLevel::Warning, &format!("session error: {error}"));
                            self.pump_rpc_events(now, registry, callbacks);
                            return Err(ConnectionError::Closed);
                        }
                    }
                    self.pump_rpc_events(now, registry, callbacks);
                }
                Incoming::QuickAck(token) => {
                    if let Some(rpc) = &mut self.rpc {
                        rpc.handle_quick_ack(token, now);
                    }
                    self.pump_rpc_events(now, registry, callbacks);
                }
                Incoming::TransportError(code) => {
                    self.log(callbacks, LogLevel::Warning, &format!("transport error {code}"));
                    self.on_transport_error(code, now, callbacks);
                    return Err(ConnectionError::Closed);
                }
                Incoming::Nop => {}
            }
        }
        self.update_progress(callbacks);
        Ok(())
    }

    fn on_transport_error(&mut self, code: i32, now: Now, callbacks: &Arc<dyn EngineCallbacks>) {
        let kind = TransportErrorKind::from_code(code);
        if self.handshake.is_some() {
            callbacks.on_event(
                self.handle,
                EngineEvent::AuthKeyCreationFailed {
                    reason: format!("transport error {code}"),
                },
            );
            if kind == TransportErrorKind::Flood {
                self.transport_floods += 1;
                callbacks.on_event(self.handle, EngineEvent::TransportFlood);
                self.next_attempt_at = self.next_attempt_at.max(now.mono + transport_flood_delay(self.transport_floods));
            }
            self.close_reason = Some(CloseReason::HandshakeFailed);
            return;
        }
        match kind {
            TransportErrorKind::AuthKeyNotFound => {
                callbacks.on_event(self.handle, EngineEvent::AuthKeyInvalid { code });
                if let Some(rpc) = self.rpc.take() {
                    for request in rpc_pending_requests(rpc) {
                        self.queued.push_back(request);
                    }
                }
                self.close_reason = Some(CloseReason::ServerRejected);
            }
            TransportErrorKind::Flood => {
                self.transport_floods += 1;
                callbacks.on_event(self.handle, EngineEvent::TransportFlood);
                if let Some(rpc) = &mut self.rpc {
                    rpc.connection_rejected(now);
                }
                self.next_attempt_at = self.next_attempt_at.max(now.mono + transport_flood_delay(self.transport_floods));
                self.close_reason = Some(CloseReason::TransportFlood);
            }
            TransportErrorKind::InvalidDc => {
                if let Some(rpc) = &mut self.rpc {
                    rpc.connection_rejected(now);
                }
                self.close_reason = Some(CloseReason::ServerRejected);
            }
            TransportErrorKind::Forbidden | TransportErrorKind::Other => {
                self.close_reason = Some(CloseReason::ServerRejected);
            }
        }
    }

    fn update_progress(&mut self, callbacks: &Arc<dyn EngineCallbacks>) {
        let (Some(connection), Some(rpc)) = (&self.connection, &self.rpc) else {
            return;
        };
        let Some((length, available)) = connection.pending_frame_head() else {
            self.progress = None;
            return;
        };
        if length < PROGRESS_THRESHOLD || available.len() < PROGRESS_HEAD {
            return;
        }
        let is_tracked = matches!(&self.progress, Some(tracking) if tracking.frame_length == length);
        if !is_tracked {
            let target = rpc.progress_target(&available[..PROGRESS_HEAD.min(available.len())]);
            self.progress = Some(ProgressTracking {
                frame_length: length,
                target,
                last_reported: 0,
            });
        }
        let tracking = self.progress.as_mut().expect("tracking exists");
        let Some(target) = tracking.target else {
            return;
        };
        let received = available.len();
        if received - tracking.last_reported >= (length / 100).max(16 * 1024) || received == length {
            tracking.last_reported = received;
            callbacks.on_event(
                self.handle,
                EngineEvent::Progress {
                    id: target,
                    progress: received as f32 / length as f32,
                    packet_length: length,
                },
            );
        }
    }

    fn pump_rpc_events(&mut self, now: Now, registry: &Registry, callbacks: &Arc<dyn EngineCallbacks>) {
        let mut reset_connection = false;
        if let Some(rpc) = &mut self.rpc {
            while let Some(event) = rpc.poll_event() {
                match &event {
                    RpcEvent::ConnectionShouldReset => {
                        reset_connection = true;
                        continue;
                    }
                    RpcEvent::TimeDifferenceUpdated { difference } => self.setup.time_difference = *difference,
                    RpcEvent::Completed { .. } | RpcEvent::Failed { .. } => self.last_activity_at = now.mono,
                    _ => {}
                }
                callbacks.on_event(self.handle, EngineEvent::Rpc(event));
            }
        }
        if reset_connection && self.connection.is_some() {
            self.close_connection(registry, now, false);
            self.next_attempt_at = now.mono;
        }
    }

    fn log(&self, callbacks: &Arc<dyn EngineCallbacks>, level: LogLevel, message: &str) {
        callbacks.on_log(level, &format!("[MTProtoEngine#{} dc{}] {message}", self.handle.0, self.setup.datacenter_id));
    }

    pub fn drive(
        &mut self,
        registry: &Registry,
        now: Now,
        resolver: &mut dyn Resolve,
        config: &EngineConfig,
        callbacks: &Arc<dyn EngineCallbacks>,
        rng: &mut OsRandom,
    ) {
        if self.rpc.is_none() && self.setup.key_generation.is_none() && !self.reported_key_required && !self.closed {
            self.reported_key_required = true;
            callbacks.on_event(self.handle, EngineEvent::AuthKeyRequired);
        }

        let wants = self.wants_connection(now);
        if !wants && self.connection.is_some() {
            self.close_connection(registry, now, false);
        }
        if wants && self.connection.is_none() && now.mono >= self.next_attempt_at {
            self.start_connection(registry, now, resolver, config, rng);
        }

        let mut failure = None;
        if let Some(connection) = &self.connection
            && !connection.is_established() && now.mono - connection.started_at > config.connect_timeout {
                failure = Some("connect timeout");
            }
        if failure.is_none() && self.handshake_started_at.is_some_and(|started| now.mono - started > HANDSHAKE_TIMEOUT) {
            callbacks.on_event(
                self.handle,
                EngineEvent::AuthKeyCreationFailed {
                    reason: "handshake timeout".into(),
                },
            );
            self.log(callbacks, LogLevel::Info, "handshake timeout");
            self.close_connection(registry, now, true);
        }
        if failure.is_none()
            && let Some(rpc) = &mut self.rpc
                && self.connection.as_ref().is_some_and(Connection::is_established) && self.handshake.is_none()
                    && let Err(error) = rpc.handle_timeout(now) {
                        failure = Some(match error {
                            SessionError::PingTimeout => "ping timeout",
                            SessionError::ReadTimeout => "read timeout",
                            _ => "session timeout",
                        });
                    }
        if failure.is_none()
            && let (Some(connection), Some(rpc)) = (&self.connection, &self.rpc)
                && connection.is_established()
                    && !self.timeout_fired
                    && rpc.has_timeout_timer_requests()
                    && now.mono - connection.last_read_at > self.setup.request_timeout
                {
                    self.timeout_fired = true;
                    failure = Some("request timeout");
                }
        self.pump_rpc_events(now, registry, callbacks);
        if let Some(reason) = failure {
            self.log(callbacks, LogLevel::Info, reason);
            let received = self.connection_received_packet();
            self.close_connection(registry, now, !received);
            if received {
                self.next_attempt_at = now.mono;
            }
        }

        self.flush_output(registry, now, callbacks, rng);
        self.report_state(now, callbacks);
        self.report_usage(now, config, callbacks);
    }

    fn flush_output(&mut self, registry: &Registry, now: Now, callbacks: &Arc<dyn EngineCallbacks>, rng: &mut OsRandom) {
        let Some(connection) = &mut self.connection else {
            return;
        };
        if !connection.is_tcp_connected() {
            return;
        }
        let mut failed = None;
        while let Some(packet) = self.pending_plain.pop_front() {
            if let Err(error) = connection.send_packet(registry, &packet, false, rng) {
                failed = Some(error);
                break;
            }
        }
        if failed.is_none() && self.handshake.is_none()
            && let Some(rpc) = &mut self.rpc
                && connection.is_established() {
                    while let Some(transmit) = rpc.poll_transmit(now, rng) {
                        if let Err(error) = connection.send_packet(registry, &transmit.data, transmit.quick_ack_token.is_some(), rng) {
                            failed = Some(error);
                            break;
                        }
                    }
                }
        if failed.is_none()
            && let Err(error) = connection.flush(registry) {
                failed = Some(error);
            }
        self.pump_rpc_events(now, registry, callbacks);
        if let Some(error) = failed {
            self.log(callbacks, LogLevel::Info, &format!("write failed: {error}"));
            self.close_connection(registry, now, true);
        }
    }

    pub fn connection_state(&self) -> (ConnectionState, Option<String>) {
        let connected = self.connection.as_ref().is_some_and(Connection::is_established);
        let received = self.connection_received_packet();
        let state = ConnectionState {
            network_available: self.network_available && !self.setup.paused,
            connected,
            updating_connection_context: connected && !received,
            performing_service_tasks: connected
                && self
                    .rpc
                    .as_ref()
                    .is_some_and(|rpc| rpc.session().is_performing_service_tasks()),
            proxy_has_connection_issues: self.setup.proxy.is_some() && !connected && self.failures >= 3,
        };
        (state, self.setup.proxy.as_ref().map(ProxyConfig::display_address))
    }

    fn report_state(&mut self, _now: Now, callbacks: &Arc<dyn EngineCallbacks>) {
        let current = self.connection_state();
        if self.last_state.as_ref() != Some(&current) {
            self.last_state = Some(current.clone());
            callbacks.on_event(
                self.handle,
                EngineEvent::ConnectionState {
                    state: current.0,
                    proxy_address: current.1,
                },
            );
        }
    }

    fn report_usage(&mut self, now: Now, config: &EngineConfig, callbacks: &Arc<dyn EngineCallbacks>) {
        if now.mono - self.last_usage_report < config.usage_report_interval {
            return;
        }
        self.last_usage_report = now.mono;
        let (mut incoming, mut outgoing) = (self.reported_in, self.reported_out);
        if let Some(connection) = &mut self.connection {
            incoming += connection.bytes_in;
            outgoing += connection.bytes_out;
            connection.bytes_in = 0;
            connection.bytes_out = 0;
        }
        self.reported_in = 0;
        self.reported_out = 0;
        if incoming > 0 || outgoing > 0 {
            callbacks.on_event(self.handle, EngineEvent::NetworkUsage { incoming, outgoing });
        }
    }

    pub fn next_deadline(&mut self, now: Now) -> Option<f64> {
        let mut deadline = f64::INFINITY;
        let wants = self.wants_connection(now);
        if wants && self.connection.is_none() {
            deadline = deadline.min(self.next_attempt_at.max(now.mono));
        }
        if let Some(started) = self.handshake_started_at {
            deadline = deadline.min(started + HANDSHAKE_TIMEOUT + 0.01);
        }
        if let Some(connection) = &self.connection {
            if !connection.is_established() {
                deadline = deadline.min(connection.started_at + 12.0);
            }
            if let Some(rpc) = &mut self.rpc
                && connection.is_established() {
                    if let Some(at) = rpc.poll_timeout(now) {
                        deadline = deadline.min(at);
                    }
                    if rpc.has_timeout_timer_requests() && !self.timeout_fired {
                        deadline = deadline.min(connection.last_read_at + self.setup.request_timeout);
                    }
                }
        } else if let Some(rpc) = &mut self.rpc
            && let Some(at) = rpc.poll_timeout(now) {
                deadline = deadline.min(at.max(now.mono + 0.5));
            }
        if let (Some(idle), Some(_)) = (self.setup.idle_disconnect_after, &self.connection)
            && !self.setup.keep_connected && !self.has_work() {
                deadline = deadline.min(self.last_activity_at + idle);
            }
        if self.reported_in > 0 || self.reported_out > 0 || self.connection.is_some() {
            deadline = deadline.min(self.last_usage_report + 2.0);
        }
        deadline.is_finite().then_some(deadline)
    }

    pub fn shrink(&mut self) {
        if let Some(connection) = &mut self.connection {
            connection.shrink();
        }
        if let Some(rpc) = &mut self.rpc {
            rpc.session_mut().shrink();
        }
    }
}

fn rpc_pending_requests(rpc: RpcClient) -> Vec<RpcRequest> {
    rpc.into_requests()
}
