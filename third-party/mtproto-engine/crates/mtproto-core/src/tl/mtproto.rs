use std::io::{Read, Write};

use flate2::read::ZlibDecoder;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;

use super::ids;
use super::{Reader, TlError, TlRead, TlResult, TlWrite, Writer};

pub const MAX_CONTAINER_MESSAGES: usize = 1024;
pub const MAX_VECTOR_ITEMS: usize = 1 << 16;
pub const MAX_UNPACKED_SIZE: usize = 64 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResPq {
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub pq: Vec<u8>,
    pub fingerprints: Vec<i64>,
}

impl<'a> TlRead<'a> for ResPq {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        reader.expect_constructor(ids::RES_PQ)?;
        Ok(Self {
            nonce: reader.read_int128()?,
            server_nonce: reader.read_int128()?,
            pq: reader.read_bytes()?.to_vec(),
            fingerprints: reader.read_i64_vector(MAX_VECTOR_ITEMS)?,
        })
    }
}

impl TlWrite for ResPq {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::RES_PQ);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_bytes(&self.pq);
        writer.write_i64_vector(&self.fingerprints);
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PqInnerData {
    pub pq: Vec<u8>,
    pub p: Vec<u8>,
    pub q: Vec<u8>,
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub new_nonce: [u8; 32],
    pub dc: i32,
    pub expires_in: Option<i32>,
}

impl TlWrite for PqInnerData {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(if self.expires_in.is_some() {
            ids::P_Q_INNER_DATA_TEMP_DC
        } else {
            ids::P_Q_INNER_DATA_DC
        });
        writer.write_bytes(&self.pq);
        writer.write_bytes(&self.p);
        writer.write_bytes(&self.q);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_int256(&self.new_nonce);
        writer.write_i32(self.dc);
        if let Some(expires_in) = self.expires_in {
            writer.write_i32(expires_in);
        }
    }
}

impl<'a> TlRead<'a> for PqInnerData {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        let offset = reader.position();
        let constructor = reader.read_u32()?;
        let temporary = match constructor {
            ids::P_Q_INNER_DATA_DC => false,
            ids::P_Q_INNER_DATA_TEMP_DC => true,
            found => return Err(TlError::UnexpectedConstructor { offset, found }),
        };
        Ok(Self {
            pq: reader.read_bytes()?.to_vec(),
            p: reader.read_bytes()?.to_vec(),
            q: reader.read_bytes()?.to_vec(),
            nonce: reader.read_int128()?,
            server_nonce: reader.read_int128()?,
            new_nonce: reader.read_int256()?,
            dc: reader.read_i32()?,
            expires_in: if temporary { Some(reader.read_i32()?) } else { None },
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ServerDhParams {
    Ok {
        nonce: [u8; 16],
        server_nonce: [u8; 16],
        encrypted_answer: Vec<u8>,
    },
    Fail {
        nonce: [u8; 16],
        server_nonce: [u8; 16],
        new_nonce_hash: [u8; 16],
    },
}

impl<'a> TlRead<'a> for ServerDhParams {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        let offset = reader.position();
        match reader.read_u32()? {
            ids::SERVER_DH_PARAMS_OK => Ok(Self::Ok {
                nonce: reader.read_int128()?,
                server_nonce: reader.read_int128()?,
                encrypted_answer: reader.read_bytes()?.to_vec(),
            }),
            ids::SERVER_DH_PARAMS_FAIL => Ok(Self::Fail {
                nonce: reader.read_int128()?,
                server_nonce: reader.read_int128()?,
                new_nonce_hash: reader.read_int128()?,
            }),
            found => Err(TlError::UnexpectedConstructor { offset, found }),
        }
    }
}

impl TlWrite for ServerDhParams {
    fn write_to(&self, writer: &mut Writer) {
        match self {
            Self::Ok {
                nonce,
                server_nonce,
                encrypted_answer,
            } => {
                writer.write_u32(ids::SERVER_DH_PARAMS_OK);
                writer.write_int128(nonce);
                writer.write_int128(server_nonce);
                writer.write_bytes(encrypted_answer);
            }
            Self::Fail {
                nonce,
                server_nonce,
                new_nonce_hash,
            } => {
                writer.write_u32(ids::SERVER_DH_PARAMS_FAIL);
                writer.write_int128(nonce);
                writer.write_int128(server_nonce);
                writer.write_int128(new_nonce_hash);
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServerDhInnerData {
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub g: i32,
    pub dh_prime: Vec<u8>,
    pub g_a: Vec<u8>,
    pub server_time: i32,
}

impl<'a> TlRead<'a> for ServerDhInnerData {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        reader.expect_constructor(ids::SERVER_DH_INNER_DATA)?;
        Ok(Self {
            nonce: reader.read_int128()?,
            server_nonce: reader.read_int128()?,
            g: reader.read_i32()?,
            dh_prime: reader.read_bytes()?.to_vec(),
            g_a: reader.read_bytes()?.to_vec(),
            server_time: reader.read_i32()?,
        })
    }
}

impl TlWrite for ServerDhInnerData {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::SERVER_DH_INNER_DATA);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_i32(self.g);
        writer.write_bytes(&self.dh_prime);
        writer.write_bytes(&self.g_a);
        writer.write_i32(self.server_time);
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientDhInnerData {
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub retry_id: i64,
    pub g_b: Vec<u8>,
}

impl TlWrite for ClientDhInnerData {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::CLIENT_DH_INNER_DATA);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_i64(self.retry_id);
        writer.write_bytes(&self.g_b);
    }
}

impl<'a> TlRead<'a> for ClientDhInnerData {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        reader.expect_constructor(ids::CLIENT_DH_INNER_DATA)?;
        Ok(Self {
            nonce: reader.read_int128()?,
            server_nonce: reader.read_int128()?,
            retry_id: reader.read_i64()?,
            g_b: reader.read_bytes()?.to_vec(),
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DhGenKind {
    Ok,
    Retry,
    Fail,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SetClientDhParamsAnswer {
    pub kind: DhGenKind,
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub new_nonce_hash: [u8; 16],
}

impl<'a> TlRead<'a> for SetClientDhParamsAnswer {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        let offset = reader.position();
        let kind = match reader.read_u32()? {
            ids::DH_GEN_OK => DhGenKind::Ok,
            ids::DH_GEN_RETRY => DhGenKind::Retry,
            ids::DH_GEN_FAIL => DhGenKind::Fail,
            found => return Err(TlError::UnexpectedConstructor { offset, found }),
        };
        Ok(Self {
            kind,
            nonce: reader.read_int128()?,
            server_nonce: reader.read_int128()?,
            new_nonce_hash: reader.read_int128()?,
        })
    }
}

impl TlWrite for SetClientDhParamsAnswer {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(match self.kind {
            DhGenKind::Ok => ids::DH_GEN_OK,
            DhGenKind::Retry => ids::DH_GEN_RETRY,
            DhGenKind::Fail => ids::DH_GEN_FAIL,
        });
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_int128(&self.new_nonce_hash);
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BindAuthKeyInner {
    pub nonce: i64,
    pub temp_auth_key_id: i64,
    pub perm_auth_key_id: i64,
    pub temp_session_id: i64,
    pub expires_at: i32,
}

impl TlWrite for BindAuthKeyInner {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::BIND_AUTH_KEY_INNER);
        writer.write_i64(self.nonce);
        writer.write_i64(self.temp_auth_key_id);
        writer.write_i64(self.perm_auth_key_id);
        writer.write_i64(self.temp_session_id);
        writer.write_i32(self.expires_at);
    }
}

impl<'a> TlRead<'a> for BindAuthKeyInner {
    fn read_from(reader: &mut Reader<'a>) -> TlResult<Self> {
        reader.expect_constructor(ids::BIND_AUTH_KEY_INNER)?;
        Ok(Self {
            nonce: reader.read_i64()?,
            temp_auth_key_id: reader.read_i64()?,
            perm_auth_key_id: reader.read_i64()?,
            temp_session_id: reader.read_i64()?,
            expires_at: reader.read_i32()?,
        })
    }
}

pub struct ReqPqMulti {
    pub nonce: [u8; 16],
}

impl TlWrite for ReqPqMulti {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::REQ_PQ_MULTI);
        writer.write_int128(&self.nonce);
    }
}

pub struct ReqDhParams<'a> {
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub p: &'a [u8],
    pub q: &'a [u8],
    pub public_key_fingerprint: i64,
    pub encrypted_data: &'a [u8],
}

impl TlWrite for ReqDhParams<'_> {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::REQ_DH_PARAMS);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_bytes(self.p);
        writer.write_bytes(self.q);
        writer.write_i64(self.public_key_fingerprint);
        writer.write_bytes(self.encrypted_data);
    }
}

pub struct SetClientDhParams<'a> {
    pub nonce: [u8; 16],
    pub server_nonce: [u8; 16],
    pub encrypted_data: &'a [u8],
}

impl TlWrite for SetClientDhParams<'_> {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::SET_CLIENT_DH_PARAMS);
        writer.write_int128(&self.nonce);
        writer.write_int128(&self.server_nonce);
        writer.write_bytes(self.encrypted_data);
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FutureSalt {
    pub valid_since: i32,
    pub valid_until: i32,
    pub salt: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RpcError {
    pub code: i32,
    pub message: String,
}

impl RpcError {
    pub fn read_body(reader: &mut Reader<'_>) -> TlResult<Self> {
        Ok(Self {
            code: reader.read_i32()?,
            message: String::from_utf8_lossy(reader.read_bytes()?).into_owned(),
        })
    }
}

impl TlWrite for RpcError {
    fn write_to(&self, writer: &mut Writer) {
        writer.write_u32(ids::RPC_ERROR);
        writer.write_i32(self.code);
        writer.write_bytes(self.message.as_bytes());
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContainerMessage<'a> {
    pub msg_id: i64,
    pub seqno: i32,
    pub body: &'a [u8],
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ServiceMessage<'a> {
    RpcResult { req_msg_id: i64, result: &'a [u8] },
    Container(Vec<ContainerMessage<'a>>),
    GzipPacked(&'a [u8]),
    Pong { msg_id: i64, ping_id: i64 },
    BadMsgNotification { bad_msg_id: i64, bad_msg_seqno: i32, error_code: i32 },
    BadServerSalt { bad_msg_id: i64, bad_msg_seqno: i32, error_code: i32, new_server_salt: i64 },
    NewSessionCreated { first_msg_id: i64, unique_id: i64, server_salt: i64 },
    MsgsAck(Vec<i64>),
    MsgDetailedInfo { msg_id: i64, answer_msg_id: i64, bytes: i32, status: i32 },
    MsgNewDetailedInfo { answer_msg_id: i64, bytes: i32, status: i32 },
    MsgResendReq(Vec<i64>),
    MsgsStateReq(Vec<i64>),
    MsgsStateInfo { req_msg_id: i64, info: &'a [u8] },
    MsgsAllInfo { msg_ids: Vec<i64>, info: &'a [u8] },
    FutureSalts { req_msg_id: i64, now: i32, salts: Vec<FutureSalt> },
    DestroySessionOk { session_id: i64 },
    DestroySessionNone { session_id: i64 },
    DestroyAuthKeyOk,
    DestroyAuthKeyNone,
    DestroyAuthKeyFail,
    Other { constructor: u32, body: &'a [u8] },
}

impl<'a> ServiceMessage<'a> {
    pub fn parse(body: &'a [u8]) -> TlResult<Self> {
        let mut reader = Reader::new(body);
        let constructor = reader.read_u32()?;
        let message = match constructor {
            ids::RPC_RESULT => Self::RpcResult {
                req_msg_id: reader.read_i64()?,
                result: take_rest(&mut reader),
            },
            ids::MSG_CONTAINER => Self::Container(parse_container_body(&mut reader)?),
            ids::GZIP_PACKED => Self::GzipPacked(reader.read_bytes()?),
            ids::PONG => Self::Pong {
                msg_id: reader.read_i64()?,
                ping_id: reader.read_i64()?,
            },
            ids::BAD_MSG_NOTIFICATION => Self::BadMsgNotification {
                bad_msg_id: reader.read_i64()?,
                bad_msg_seqno: reader.read_i32()?,
                error_code: reader.read_i32()?,
            },
            ids::BAD_SERVER_SALT => Self::BadServerSalt {
                bad_msg_id: reader.read_i64()?,
                bad_msg_seqno: reader.read_i32()?,
                error_code: reader.read_i32()?,
                new_server_salt: reader.read_i64()?,
            },
            ids::NEW_SESSION_CREATED => Self::NewSessionCreated {
                first_msg_id: reader.read_i64()?,
                unique_id: reader.read_i64()?,
                server_salt: reader.read_i64()?,
            },
            ids::MSGS_ACK => Self::MsgsAck(reader.read_i64_vector(MAX_VECTOR_ITEMS)?),
            ids::MSG_DETAILED_INFO => Self::MsgDetailedInfo {
                msg_id: reader.read_i64()?,
                answer_msg_id: reader.read_i64()?,
                bytes: reader.read_i32()?,
                status: reader.read_i32()?,
            },
            ids::MSG_NEW_DETAILED_INFO => Self::MsgNewDetailedInfo {
                answer_msg_id: reader.read_i64()?,
                bytes: reader.read_i32()?,
                status: reader.read_i32()?,
            },
            ids::MSG_RESEND_REQ | ids::MSG_RESEND_ANS_REQ => {
                Self::MsgResendReq(reader.read_i64_vector(MAX_VECTOR_ITEMS)?)
            }
            ids::MSGS_STATE_REQ => Self::MsgsStateReq(reader.read_i64_vector(MAX_VECTOR_ITEMS)?),
            ids::MSGS_STATE_INFO => Self::MsgsStateInfo {
                req_msg_id: reader.read_i64()?,
                info: reader.read_bytes()?,
            },
            ids::MSGS_ALL_INFO => Self::MsgsAllInfo {
                msg_ids: reader.read_i64_vector(MAX_VECTOR_ITEMS)?,
                info: reader.read_bytes()?,
            },
            ids::FUTURE_SALTS => {
                let req_msg_id = reader.read_i64()?;
                let now = reader.read_i32()?;
                let count = reader.read_vector_header_or_bare(MAX_VECTOR_ITEMS)?;
                let mut salts = Vec::with_capacity(count.min(64));
                for _ in 0..count {
                    if reader.peek_u32()? == ids::FUTURE_SALT {
                        reader.read_u32()?;
                    }
                    salts.push(FutureSalt {
                        valid_since: reader.read_i32()?,
                        valid_until: reader.read_i32()?,
                        salt: reader.read_i64()?,
                    });
                }
                Self::FutureSalts { req_msg_id, now, salts }
            }
            ids::DESTROY_SESSION_OK => Self::DestroySessionOk {
                session_id: reader.read_i64()?,
            },
            ids::DESTROY_SESSION_NONE => Self::DestroySessionNone {
                session_id: reader.read_i64()?,
            },
            ids::DESTROY_AUTH_KEY_OK => Self::DestroyAuthKeyOk,
            ids::DESTROY_AUTH_KEY_NONE => Self::DestroyAuthKeyNone,
            ids::DESTROY_AUTH_KEY_FAIL => Self::DestroyAuthKeyFail,
            _ => {
                return Ok(Self::Other {
                    constructor,
                    body,
                });
            }
        };
        Ok(message)
    }
}

impl Reader<'_> {
    fn read_vector_header_or_bare(&mut self, max_count: usize) -> TlResult<usize> {
        if self.peek_u32()? == ids::VECTOR {
            self.read_vector_header(max_count)
        } else {
            self.read_count(max_count)
        }
    }
}

fn take_rest<'a>(reader: &mut Reader<'a>) -> &'a [u8] {
    let rest = reader.rest();
    reader.skip(rest.len()).expect("rest is available");
    rest
}

fn parse_container_body<'a>(reader: &mut Reader<'a>) -> TlResult<Vec<ContainerMessage<'a>>> {
    let count = reader.read_count(MAX_CONTAINER_MESSAGES)?;
    let mut messages = Vec::with_capacity(count);
    for _ in 0..count {
        let msg_id = reader.read_i64()?;
        let seqno = reader.read_i32()?;
        let offset = reader.position();
        let length = reader.read_i32()?;
        if length < 0 || length % 4 != 0 || length as usize > reader.remaining() {
            return Err(TlError::InvalidLength {
                offset,
                length: length as i64,
            });
        }
        let body = reader.read_raw(length as usize)?;
        messages.push(ContainerMessage { msg_id, seqno, body });
    }
    Ok(messages)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RpcResultBody<'a> {
    Error(RpcError),
    Value(&'a [u8]),
    PackedValue(Vec<u8>),
    DropAnswer(RpcDropAnswer),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RpcDropAnswer {
    Unknown,
    DroppedRunning,
    Dropped { msg_id: i64, seq_no: i32, bytes: i32 },
}

pub fn parse_rpc_result(result: &[u8]) -> TlResult<RpcResultBody<'_>> {
    let mut reader = Reader::new(result);
    match reader.read_u32()? {
        ids::RPC_ERROR => Ok(RpcResultBody::Error(RpcError::read_body(&mut reader)?)),
        ids::GZIP_PACKED => {
            let unpacked = gunzip(reader.read_bytes()?, MAX_UNPACKED_SIZE)?;
            if unpacked.len() >= 4 && u32::from_le_bytes(unpacked[..4].try_into().expect("4 bytes")) == ids::RPC_ERROR {
                let mut inner = Reader::new(&unpacked[4..]);
                return Ok(RpcResultBody::Error(RpcError::read_body(&mut inner)?));
            }
            Ok(RpcResultBody::PackedValue(unpacked))
        }
        ids::RPC_ANSWER_UNKNOWN => Ok(RpcResultBody::DropAnswer(RpcDropAnswer::Unknown)),
        ids::RPC_ANSWER_DROPPED_RUNNING => Ok(RpcResultBody::DropAnswer(RpcDropAnswer::DroppedRunning)),
        ids::RPC_ANSWER_DROPPED => Ok(RpcResultBody::DropAnswer(RpcDropAnswer::Dropped {
            msg_id: reader.read_i64()?,
            seq_no: reader.read_i32()?,
            bytes: reader.read_i32()?,
        })),
        _ => Ok(RpcResultBody::Value(result)),
    }
}

pub fn gunzip(data: &[u8], limit: usize) -> TlResult<Vec<u8>> {
    let mut output = Vec::with_capacity((data.len() * 4).min(limit));
    let read = if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
        GzDecoder::new(data).take(limit as u64 + 1).read_to_end(&mut output)
    } else {
        ZlibDecoder::new(data).take(limit as u64 + 1).read_to_end(&mut output)
    };
    read.map_err(|error| TlError::Gzip(error.to_string()))?;
    if output.len() > limit {
        return Err(TlError::Gzip(format!("unpacked size exceeds {limit} bytes")));
    }
    Ok(output)
}

pub fn gzip(data: &[u8]) -> Vec<u8> {
    let mut encoder = GzEncoder::new(Vec::with_capacity(data.len() / 2 + 32), Compression::default());
    encoder.write_all(data).expect("writing to a Vec cannot fail");
    encoder.finish().expect("writing to a Vec cannot fail")
}

pub fn write_gzip_packed(writer: &mut Writer, packed: &[u8]) {
    writer.write_u32(ids::GZIP_PACKED);
    writer.write_bytes(packed);
}

pub fn write_msgs_ack(writer: &mut Writer, msg_ids: &[i64]) {
    writer.write_u32(ids::MSGS_ACK);
    writer.write_i64_vector(msg_ids);
}

pub fn write_ping(writer: &mut Writer, ping_id: i64) {
    writer.write_u32(ids::PING);
    writer.write_i64(ping_id);
}

pub fn write_ping_delay_disconnect(writer: &mut Writer, ping_id: i64, disconnect_delay: i32) {
    writer.write_u32(ids::PING_DELAY_DISCONNECT);
    writer.write_i64(ping_id);
    writer.write_i32(disconnect_delay);
}

pub fn write_get_future_salts(writer: &mut Writer, num: i32) {
    writer.write_u32(ids::GET_FUTURE_SALTS);
    writer.write_i32(num);
}

pub fn write_msgs_state_req(writer: &mut Writer, msg_ids: &[i64]) {
    writer.write_u32(ids::MSGS_STATE_REQ);
    writer.write_i64_vector(msg_ids);
}

pub fn write_msgs_state_info(writer: &mut Writer, req_msg_id: i64, info: &[u8]) {
    writer.write_u32(ids::MSGS_STATE_INFO);
    writer.write_i64(req_msg_id);
    writer.write_bytes(info);
}

pub fn write_msg_resend_req(writer: &mut Writer, msg_ids: &[i64]) {
    writer.write_u32(ids::MSG_RESEND_REQ);
    writer.write_i64_vector(msg_ids);
}

pub fn write_destroy_session(writer: &mut Writer, session_id: i64) {
    writer.write_u32(ids::DESTROY_SESSION);
    writer.write_i64(session_id);
}

pub fn write_rpc_drop_answer(writer: &mut Writer, req_msg_id: i64) {
    writer.write_u32(ids::RPC_DROP_ANSWER);
    writer.write_i64(req_msg_id);
}

pub fn write_http_wait(writer: &mut Writer, max_delay: i32, wait_after: i32, max_wait: i32) {
    writer.write_u32(ids::HTTP_WAIT);
    writer.write_i32(max_delay);
    writer.write_i32(wait_after);
    writer.write_i32(max_wait);
}

pub fn write_destroy_auth_key(writer: &mut Writer) {
    writer.write_u32(ids::DESTROY_AUTH_KEY);
}

pub fn write_container(writer: &mut Writer, messages: &[ContainerMessage<'_>]) {
    writer.write_u32(ids::MSG_CONTAINER);
    writer.write_i32(i32::try_from(messages.len()).expect("container too large"));
    for message in messages {
        writer.write_i64(message.msg_id);
        writer.write_i32(message.seqno);
        writer.write_i32(i32::try_from(message.body.len()).expect("message too large"));
        writer.write_raw(message.body);
    }
}

pub fn write_invoke_after_msg(writer: &mut Writer, msg_id: i64) {
    writer.write_u32(ids::INVOKE_AFTER_MSG);
    writer.write_i64(msg_id);
}

pub fn write_rpc_result(writer: &mut Writer, req_msg_id: i64, result: &[u8]) {
    writer.write_u32(ids::RPC_RESULT);
    writer.write_i64(req_msg_id);
    writer.write_raw(result);
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn res_pq_roundtrip() {
        let value = ResPq {
            nonce: [1; 16],
            server_nonce: [2; 16],
            pq: vec![0x17, 0xED, 0x48, 0x94, 0x1A, 0x08, 0xF9, 0x81],
            fingerprints: vec![-4344800451088585951],
        };
        assert_eq!(ResPq::from_bytes(&value.to_bytes()).unwrap(), value);
    }

    #[test]
    fn pq_inner_data_variants() {
        let mut value = PqInnerData {
            pq: vec![1, 2],
            p: vec![3],
            q: vec![4],
            nonce: [5; 16],
            server_nonce: [6; 16],
            new_nonce: [7; 32],
            dc: -2,
            expires_in: None,
        };
        let bytes = value.to_bytes();
        assert_eq!(&bytes[..4], &ids::P_Q_INNER_DATA_DC.to_le_bytes());
        assert_eq!(PqInnerData::from_bytes(&bytes).unwrap(), value);
        value.expires_in = Some(86400);
        let bytes = value.to_bytes();
        assert_eq!(&bytes[..4], &ids::P_Q_INNER_DATA_TEMP_DC.to_le_bytes());
        assert_eq!(PqInnerData::from_bytes(&bytes).unwrap(), value);
    }

    #[test]
    fn container_parse_and_limits() {
        let first = 7i64.to_le_bytes();
        let second = [1u8, 2, 3, 4, 5, 6, 7, 8];
        let messages = [
            ContainerMessage { msg_id: 10, seqno: 1, body: &first },
            ContainerMessage { msg_id: 14, seqno: 3, body: &second },
        ];
        let mut writer = Writer::new();
        write_container(&mut writer, &messages);
        match ServiceMessage::parse(writer.as_slice()).unwrap() {
            ServiceMessage::Container(parsed) => assert_eq!(parsed, messages),
            other => panic!("unexpected {other:?}"),
        }

        let mut bad = Writer::new();
        bad.write_u32(ids::MSG_CONTAINER);
        bad.write_i32(1);
        bad.write_i64(1);
        bad.write_i32(1);
        bad.write_i32(6);
        bad.write_raw(&[0; 8]);
        assert!(ServiceMessage::parse(bad.as_slice()).is_err());

        let mut overflow = Writer::new();
        overflow.write_u32(ids::MSG_CONTAINER);
        overflow.write_i32(1);
        overflow.write_i64(1);
        overflow.write_i32(1);
        overflow.write_i32(64);
        overflow.write_raw(&[0; 8]);
        assert!(ServiceMessage::parse(overflow.as_slice()).is_err());

        let mut too_many = Writer::new();
        too_many.write_u32(ids::MSG_CONTAINER);
        too_many.write_i32(MAX_CONTAINER_MESSAGES as i32 + 1);
        assert!(ServiceMessage::parse(too_many.as_slice()).is_err());
    }

    #[test]
    fn rpc_result_variants() {
        let mut error = Writer::new();
        RpcError { code: 420, message: "FLOOD_WAIT_3".into() }.write_to(&mut error);
        assert_eq!(
            parse_rpc_result(error.as_slice()).unwrap(),
            RpcResultBody::Error(RpcError { code: 420, message: "FLOOD_WAIT_3".into() })
        );

        let payload = {
            let mut w = Writer::new();
            w.write_u32(0x1234_5678);
            w.write_bytes(&vec![9u8; 5000]);
            w.into_inner()
        };
        let mut packed = Writer::new();
        write_gzip_packed(&mut packed, &gzip(&payload));
        assert_eq!(parse_rpc_result(packed.as_slice()).unwrap(), RpcResultBody::PackedValue(payload.clone()));

        let mut packed_error = Writer::new();
        write_gzip_packed(&mut packed_error, &gzip(&error.clone().into_inner()));
        assert!(matches!(parse_rpc_result(packed_error.as_slice()).unwrap(), RpcResultBody::Error(_)));

        assert_eq!(parse_rpc_result(&payload).unwrap(), RpcResultBody::Value(&payload));

        let mut dropped = Writer::new();
        dropped.write_u32(ids::RPC_ANSWER_DROPPED);
        dropped.write_i64(5);
        dropped.write_i32(7);
        dropped.write_i32(100);
        assert_eq!(
            parse_rpc_result(dropped.as_slice()).unwrap(),
            RpcResultBody::DropAnswer(RpcDropAnswer::Dropped { msg_id: 5, seq_no: 7, bytes: 100 })
        );
    }

    #[test]
    fn gunzip_enforces_limit() {
        let data = vec![0u8; 100_000];
        let packed = gzip(&data);
        assert_eq!(gunzip(&packed, 100_000).unwrap(), data);
        assert!(gunzip(&packed, 99_999).is_err());
        assert!(gunzip(&[1, 2, 3, 4], 100).is_err());
    }

    #[test]
    fn future_salts_accepts_bare_and_boxed_items() {
        for boxed in [false, true] {
            let mut writer = Writer::new();
            writer.write_u32(ids::FUTURE_SALTS);
            writer.write_i64(99);
            writer.write_i32(1000);
            if boxed {
                writer.write_u32(ids::VECTOR);
            }
            writer.write_i32(2);
            for salt in [1i64, 2] {
                if boxed {
                    writer.write_u32(ids::FUTURE_SALT);
                }
                writer.write_i32(900 + salt as i32);
                writer.write_i32(2000 + salt as i32);
                writer.write_i64(salt);
            }
            match ServiceMessage::parse(writer.as_slice()).unwrap() {
                ServiceMessage::FutureSalts { req_msg_id, now, salts } => {
                    assert_eq!(req_msg_id, 99);
                    assert_eq!(now, 1000);
                    assert_eq!(salts.len(), 2);
                    assert_eq!(salts[1].salt, 2);
                }
                other => panic!("unexpected {other:?}"),
            }
        }
    }

    #[test]
    fn unknown_constructor_is_passed_through() {
        let body = [0xaa, 0xbb, 0xcc, 0xdd, 1, 2, 3, 4];
        assert_eq!(
            ServiceMessage::parse(&body).unwrap(),
            ServiceMessage::Other { constructor: 0xddccbbaa, body: &body }
        );
    }

    proptest! {
        #[test]
        fn service_parser_never_panics(data in proptest::collection::vec(any::<u8>(), 0..256), constructor in prop::sample::select(vec![
            ids::RPC_RESULT, ids::MSG_CONTAINER, ids::GZIP_PACKED, ids::PONG, ids::BAD_MSG_NOTIFICATION,
            ids::BAD_SERVER_SALT, ids::NEW_SESSION_CREATED, ids::MSGS_ACK, ids::MSG_DETAILED_INFO,
            ids::MSG_NEW_DETAILED_INFO, ids::MSG_RESEND_REQ, ids::MSGS_STATE_REQ, ids::MSGS_STATE_INFO,
            ids::MSGS_ALL_INFO, ids::FUTURE_SALTS, ids::DESTROY_SESSION_OK])) {
            let mut body = constructor.to_le_bytes().to_vec();
            body.extend_from_slice(&data);
            let _ = ServiceMessage::parse(&body);
            let _ = parse_rpc_result(&body);
        }
    }
}
