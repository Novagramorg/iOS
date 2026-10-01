mod dedupe;
mod salts;

use std::collections::{HashMap, VecDeque};

pub use dedupe::{DuplicateCheck, DuplicateChecker};
pub use salts::{SaltState, ServerSalt, SALT_SAFETY_MARGIN, SINGLE_SALT_LIFETIME};

use crate::auth_key::AuthKey;
use crate::crypto::{aes_ige_decrypt, message_key_v2, SecureRandom, Side};
use crate::message::{decrypt_message, encrypt_message, read_auth_key_id, MessageError, MessageHeader, PaddingPolicy};
use crate::msg_id::{msg_id_for_time, msg_id_time, MSG_ID_MAX_FUTURE_SECONDS, MSG_ID_MAX_PAST_SECONDS};
use crate::tl::mtproto::{self as tlm, ContainerMessage, FutureSalt, RpcResultBody, ServiceMessage};
use crate::tl::{ids, Reader, TlError, Writer};

pub const ACK_DELAY: f64 = 30.0;
pub const MAX_PENDING_ACKS: usize = 100;
pub const QUERY_DELAY: f64 = 0.001;
pub const FUTURE_SALTS_RETRY: f64 = 60.0;
pub const FUTURE_SALTS_COUNT: i32 = 64;
pub const MAX_IDS_PER_SERVICE_MESSAGE: usize = 8192;
pub const STATE_REQUEST_RETRY: f64 = 20.0;
pub const DEFAULT_CONTAINER_BYTES: usize = 1 << 15;
pub const DEFAULT_CONTAINER_QUERIES: usize = 1000;
pub const MAX_RECENT_QUICK_ACKS: usize = 256;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Now {
    pub mono: f64,
    pub unix: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct QueryId(pub u64);

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct QueryOptions {
    pub quick_ack: bool,
    pub invoke_after: Option<QueryId>,
}

#[derive(Debug, Clone)]
pub struct SessionConfig {
    pub is_main: bool,
    pub padding: PaddingPolicy,
    pub max_container_bytes: usize,
    pub max_container_queries: usize,
    pub use_ping_delay_disconnect: bool,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            is_main: true,
            padding: PaddingPolicy::default(),
            max_container_bytes: DEFAULT_CONTAINER_BYTES,
            max_container_queries: DEFAULT_CONTAINER_QUERIES,
            use_ping_delay_disconnect: true,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum SessionEvent {
    Result { id: QueryId, body: Vec<u8>, response_msg_id: i64, original_size: usize },
    Error { id: QueryId, code: i32, message: String, response_msg_id: i64 },
    Acknowledged { id: QueryId },
    Update { body: Vec<u8>, msg_id: i64 },
    ServerSessionReset { unique_id: i64, first_msg_id: i64 },
    LocalSessionReset { previous_session_id: i64 },
    TimeDifferenceUpdated { difference: f64, forced: bool },
    SaltsUpdated { salts: Vec<ServerSalt> },
    Pong { rtt: f64 },
    DroppedAnswerTooLarge { total: usize },
    DestroyAuthKey { outcome: DestroyAuthKeyOutcome },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DestroyAuthKeyOutcome {
    Ok,
    None,
    Fail,
}

#[derive(Debug, Clone, PartialEq, thiserror::Error)]
pub enum SessionError {
    #[error("decryption failed: {0}")]
    Decrypt(#[from] MessageError),
    #[error("malformed packet: {0}")]
    Malformed(#[from] TlError),
    #[error("packet from foreign session")]
    ForeignSession,
    #[error("server msg_id {0:#x} has even parity")]
    EvenServerMsgId(i64),
    #[error("message is too old to be processed")]
    TooOld,
    #[error("ping timeout")]
    PingTimeout,
    #[error("read timeout")]
    ReadTimeout,
    #[error("server reported a fatal session error {0}")]
    BadMessage(i32),
    #[error("too many dropped answers")]
    TooManyDroppedAnswers,
    #[error("no state information received for unknown queries")]
    UnknownQueriesStuck,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CancelOutcome {
    NotFound,
    Removed,
    RemovedInFlight { msg_id: i64 },
}

#[derive(Debug, Clone)]
pub struct Transmit {
    pub data: Vec<u8>,
    pub quick_ack_token: Option<u32>,
    pub msg_id: i64,
    pub contains_queries: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum QueryState {
    Pending,
    Sent,
    Unknown,
}

#[derive(Debug, Clone)]
struct Query {
    body: Vec<u8>,
    options: QueryOptions,
    state: QueryState,
    msg_id: i64,
    seq_no: i32,
    container_id: i64,
    acknowledged: bool,
    ack_reported: bool,
    sent_at: f64,
    connection_epoch: u64,
}

#[derive(Debug, Clone)]
enum ServiceRequest {
    StateRequest { msg_ids: Vec<i64> },
    ResendRequest { msg_ids: Vec<i64> },
}

pub struct Session {
    config: SessionConfig,
    auth_key: AuthKey,
    session_id: i64,
    salts: SaltState,
    time_difference: f64,
    time_synchronized: bool,
    last_msg_id: i64,
    seq_no: i32,

    queries: HashMap<QueryId, Query>,
    pending: VecDeque<QueryId>,
    by_msg_id: HashMap<i64, QueryId>,
    containers: HashMap<i64, Vec<i64>>,
    quick_acks: VecDeque<(u32, Vec<QueryId>)>,

    to_ack: Vec<i64>,
    to_resend_answer: Vec<i64>,
    to_state_request: Vec<i64>,
    to_drop_answer: Vec<i64>,
    to_state_info_reply: Vec<(i64, Vec<u8>)>,
    service_requests: HashMap<i64, ServiceRequest>,
    service_containers: HashMap<i64, Vec<i64>>,
    force_send_at: Option<f64>,

    received: DuplicateChecker,
    updates: DuplicateChecker,

    connected: bool,
    connection_epoch: u64,
    connected_at: f64,
    online: bool,
    random_delay: f64,
    rtt: f64,
    last_read_at: f64,
    last_pong_at: f64,
    last_ping_at: Option<f64>,
    last_ping_msg_id: i64,
    last_ping_container_id: i64,
    pending_pings: HashMap<i64, f64>,
    last_future_salts_at: Option<f64>,
    unknown_since: Option<f64>,
    dropped_answer_bytes: usize,

    need_destroy_auth_key: bool,
    sent_destroy_auth_key: bool,
    pending_reset: bool,

    events: VecDeque<SessionEvent>,
}

impl Session {
    pub fn new(
        config: SessionConfig,
        auth_key: AuthKey,
        salts: &[ServerSalt],
        time_difference: f64,
        now: Now,
        rng: &mut impl SecureRandom,
    ) -> Self {
        let server_time = now.unix + time_difference;
        let random_delay = (rng.next_u32() % 5_000_000) as f64 * 1e-6;
        Self {
            config,
            auth_key,
            session_id: rng.next_u64() as i64,
            salts: SaltState::from_salts(salts, server_time),
            time_difference,
            time_synchronized: false,
            last_msg_id: 0,
            seq_no: 0,
            queries: HashMap::new(),
            pending: VecDeque::new(),
            by_msg_id: HashMap::new(),
            containers: HashMap::new(),
            quick_acks: VecDeque::new(),
            to_ack: Vec::new(),
            to_resend_answer: Vec::new(),
            to_state_request: Vec::new(),
            to_drop_answer: Vec::new(),
            to_state_info_reply: Vec::new(),
            service_requests: HashMap::new(),
            service_containers: HashMap::new(),
            force_send_at: None,
            received: DuplicateChecker::new(1000),
            updates: DuplicateChecker::new(1000),
            connected: false,
            connection_epoch: 0,
            connected_at: now.mono,
            online: false,
            random_delay,
            rtt: 0.0,
            last_read_at: now.mono,
            last_pong_at: now.mono,
            last_ping_at: None,
            last_ping_msg_id: 0,
            last_ping_container_id: 0,
            pending_pings: HashMap::new(),
            last_future_salts_at: None,
            unknown_since: None,
            dropped_answer_bytes: 0,
            need_destroy_auth_key: false,
            sent_destroy_auth_key: false,
            pending_reset: false,
            events: VecDeque::new(),
        }
    }

    pub fn session_id(&self) -> i64 {
        self.session_id
    }

    pub fn auth_key(&self) -> &AuthKey {
        &self.auth_key
    }

    pub fn auth_key_id(&self) -> u64 {
        self.auth_key.id()
    }

    pub fn time_difference(&self) -> f64 {
        self.time_difference
    }

    pub fn salts(&self) -> Vec<ServerSalt> {
        self.salts.all()
    }

    pub fn is_connected(&self) -> bool {
        self.connected
    }

    pub fn has_queries(&self) -> bool {
        !self.queries.is_empty()
    }

    pub fn query_count(&self) -> usize {
        self.queries.len()
    }

    pub fn has_unanswered_queries(&self) -> bool {
        self.queries.values().any(|query| query.state != QueryState::Pending)
    }

    pub fn has_unknown_queries(&self) -> bool {
        self.queries.values().any(|query| query.state == QueryState::Unknown)
    }

    pub fn is_performing_service_tasks(&self) -> bool {
        self.has_unknown_queries() || !self.service_requests.is_empty() || !self.to_resend_answer.is_empty()
    }

    pub fn query_msg_id(&self, id: QueryId) -> Option<i64> {
        self.queries.get(&id).filter(|query| query.state != QueryState::Pending).map(|query| query.msg_id)
    }

    pub fn contains(&self, id: QueryId) -> bool {
        self.queries.contains_key(&id)
    }

    pub fn set_online(&mut self, online: bool, now: Now) {
        let need_ping = online || !self.online;
        self.online = online;
        if need_ping {
            self.last_pong_at = now.mono - self.ping_disconnect_delay() + self.rtt_estimate();
            self.last_read_at = now.mono - self.read_disconnect_delay() + self.rtt_estimate();
        } else {
            self.last_pong_at = now.mono;
            self.last_read_at = now.mono;
        }
        self.last_ping_at = None;
        self.last_ping_msg_id = 0;
        self.last_ping_container_id = 0;
    }

    pub fn set_time_difference(&mut self, difference: f64) {
        self.time_difference = difference;
    }

    pub fn replace_auth_key(&mut self, auth_key: AuthKey, salts: &[ServerSalt], now: Now) {
        if auth_key.id() != self.auth_key.id() {
            self.auth_key = auth_key;
            self.salts = SaltState::from_salts(salts, self.server_time(now));
        }
    }

    pub fn merge_salts(&mut self, salts: &[ServerSalt], now: Now) {
        let server_time = self.server_time(now);
        let future: Vec<ServerSalt> = salts.iter().copied().filter(|salt| salt.valid_until > server_time).collect();
        if !future.is_empty() {
            self.salts.set_future(future, server_time);
        }
    }

    pub fn request_destroy_auth_key(&mut self) {
        self.need_destroy_auth_key = true;
    }

    fn server_time(&self, now: Now) -> f64 {
        now.unix + self.time_difference
    }

    fn rtt_estimate(&self) -> f64 {
        (self.rtt * 1.5 + 1.0).max(2.0)
    }

    pub fn read_disconnect_delay(&self) -> f64 {
        if self.online {
            self.rtt_estimate() * 3.5
        } else {
            135.0 + self.random_delay
        }
    }

    pub fn ping_disconnect_delay(&self) -> f64 {
        if self.online && self.config.is_main {
            self.rtt_estimate() * 2.5
        } else {
            135.0 + self.random_delay
        }
    }

    fn ping_may_delay(&self) -> f64 {
        if self.online {
            self.rtt_estimate() * 0.5
        } else {
            30.0 + self.random_delay
        }
    }

    fn ping_must_delay(&self) -> f64 {
        if self.online {
            self.rtt_estimate()
        } else {
            60.0 + self.random_delay
        }
    }

    fn next_msg_id(&mut self, now: Now, rng: &mut impl SecureRandom) -> i64 {
        let server_time = self.server_time(now);
        let random = rng.next_u32();
        let base = msg_id_for_time(server_time) ^ (random & ((1 << 22) - 1)) as i64;
        let mut id = base & !3;
        if id <= self.last_msg_id {
            id = self.last_msg_id + 8 * (((random >> 22) & 1023) as i64 + 1);
        }
        self.last_msg_id = id;
        id
    }

    fn next_seq_no(&mut self, content_related: bool) -> i32 {
        let seq_no = self.seq_no;
        if content_related {
            self.seq_no += 2;
            seq_no | 1
        } else {
            seq_no
        }
    }

    fn send_before(&mut self, at: f64) {
        self.force_send_at = Some(match self.force_send_at {
            Some(existing) if existing <= at => existing,
            _ => at,
        });
    }

    pub fn send(&mut self, id: QueryId, body: Vec<u8>, options: QueryOptions, now: Now) {
        debug_assert!(body.len() % 4 == 0, "query body must be 4-byte aligned");
        if self.queries.contains_key(&id) {
            return;
        }
        self.queries.insert(
            id,
            Query {
                body,
                options,
                state: QueryState::Pending,
                msg_id: 0,
                seq_no: 0,
                container_id: 0,
                acknowledged: false,
                ack_reported: false,
                sent_at: 0.0,
                connection_epoch: 0,
            },
        );
        self.pending.push_back(id);
        self.send_before(now.mono + QUERY_DELAY);
    }

    pub fn cancel(&mut self, id: QueryId) -> CancelOutcome {
        let Some(query) = self.queries.remove(&id) else {
            return CancelOutcome::NotFound;
        };
        match query.state {
            QueryState::Pending => {
                self.pending.retain(|pending| *pending != id);
                CancelOutcome::Removed
            }
            QueryState::Sent | QueryState::Unknown => {
                self.by_msg_id.remove(&query.msg_id);
                CancelOutcome::RemovedInFlight { msg_id: query.msg_id }
            }
        }
    }

    pub fn drop_answer(&mut self, msg_id: i64, now: Now) {
        self.to_drop_answer.push(msg_id);
        self.send_before(now.mono);
    }

    pub fn connection_opened(&mut self, now: Now) {
        self.connected = true;
        self.connection_epoch += 1;
        self.connected_at = now.mono;
        self.last_read_at = now.mono;
        self.last_pong_at = now.mono;
        self.last_ping_at = None;
        self.last_ping_msg_id = 0;
        self.last_ping_container_id = 0;
        self.pending_pings.clear();
        self.quick_acks.clear();
        let unknown: Vec<i64> = self
            .queries
            .values()
            .filter(|query| query.state == QueryState::Unknown)
            .map(|query| query.msg_id)
            .collect();
        if !unknown.is_empty() {
            self.to_state_request.extend(unknown);
            self.unknown_since.get_or_insert(now.mono);
            self.send_before(now.mono);
        }
        if !self.pending.is_empty() || !self.to_ack.is_empty() {
            self.send_before(now.mono);
        }
    }

    pub fn connection_closed(&mut self) {
        if !self.connected {
            return;
        }
        self.connected = false;
        let epoch = self.connection_epoch;
        for query in self.queries.values_mut() {
            if query.state == QueryState::Sent && !query.acknowledged && query.connection_epoch == epoch {
                query.state = QueryState::Unknown;
            }
        }
        self.to_state_request.clear();
        self.service_requests.clear();
        self.service_containers.clear();
        self.quick_acks.clear();
        self.pending_pings.clear();
    }

    pub fn reset(&mut self, rng: &mut impl SecureRandom) {
        let previous_session_id = self.session_id;
        self.session_id = rng.next_u64() as i64;
        self.seq_no = 0;
        self.last_msg_id = 0;
        self.by_msg_id.clear();
        self.containers.clear();
        self.quick_acks.clear();
        self.to_ack.clear();
        self.to_resend_answer.clear();
        self.to_state_request.clear();
        self.to_drop_answer.clear();
        self.to_state_info_reply.clear();
        self.service_requests.clear();
        self.service_containers.clear();
        self.pending_pings.clear();
        self.received.clear();
        self.updates.clear();
        self.unknown_since = None;
        self.last_ping_at = None;
        self.last_ping_msg_id = 0;
        self.last_ping_container_id = 0;
        let mut resend: Vec<(i64, QueryId)> = self
            .queries
            .iter()
            .filter(|(_, query)| query.state != QueryState::Pending)
            .map(|(id, query)| (query.msg_id, *id))
            .collect();
        resend.sort_unstable();
        for (_, id) in resend.into_iter().rev() {
            self.requeue_front(id);
        }
        self.events.push_back(SessionEvent::LocalSessionReset { previous_session_id });
    }

    fn requeue_front(&mut self, id: QueryId) {
        if let Some(query) = self.queries.get_mut(&id) {
            if query.state != QueryState::Pending {
                self.by_msg_id.remove(&query.msg_id);
                query.state = QueryState::Pending;
                query.msg_id = 0;
                query.container_id = 0;
                query.acknowledged = false;
                self.pending.push_front(id);
            }
        }
    }

    fn resend_query(&mut self, id: QueryId, now: Now) {
        let mut position = 0;
        if let Some(query) = self.queries.get(&id) {
            if query.state == QueryState::Pending {
                return;
            }
            let msg_id = query.msg_id;
            position = self
                .pending
                .iter()
                .position(|other| self.queries.get(other).is_some_and(|other| other.msg_id > msg_id))
                .unwrap_or(self.pending.len());
        }
        if let Some(query) = self.queries.get_mut(&id) {
            self.by_msg_id.remove(&query.msg_id);
            query.state = QueryState::Pending;
            query.msg_id = 0;
            query.container_id = 0;
            query.acknowledged = false;
            self.pending.insert(position.min(self.pending.len()), id);
            self.send_before(now.mono);
        }
    }

    fn message_failed(&mut self, msg_id: i64, now: Now) {
        if msg_id == self.last_ping_msg_id || msg_id == self.last_ping_container_id {
            self.last_ping_at = None;
            self.last_ping_msg_id = 0;
            self.last_ping_container_id = 0;
        }
        self.sent_destroy_auth_key = false;
        let mut targets = vec![msg_id];
        if let Some(children) = self.containers.remove(&msg_id) {
            targets.extend(children);
        }
        if let Some(children) = self.service_containers.remove(&msg_id) {
            targets.extend(children);
        }
        for target in targets {
            if let Some(id) = self.by_msg_id.get(&target).copied() {
                self.resend_query(id, now);
            }
            if let Some(service) = self.service_requests.remove(&target) {
                match service {
                    ServiceRequest::StateRequest { msg_ids } => {
                        self.to_state_request.extend(msg_ids);
                    }
                    ServiceRequest::ResendRequest { msg_ids } => {
                        self.to_resend_answer.extend(msg_ids);
                    }
                }
                self.send_before(now.mono);
            }
            if self.pending_pings.remove(&target).is_some() {
                self.last_ping_at = None;
            }
        }
    }

    fn acknowledge(&mut self, msg_id: i64) {
        let mut targets = vec![msg_id];
        if let Some(children) = self.containers.get(&msg_id) {
            targets.extend(children.iter().copied());
        }
        for target in targets {
            if let Some(id) = self.by_msg_id.get(&target).copied() {
                self.mark_acknowledged(id);
            }
        }
    }

    fn mark_acknowledged(&mut self, id: QueryId) {
        if let Some(query) = self.queries.get_mut(&id) {
            if query.state == QueryState::Unknown {
                query.state = QueryState::Sent;
            }
            query.acknowledged = true;
            if !query.ack_reported {
                query.ack_reported = true;
                self.events.push_back(SessionEvent::Acknowledged { id });
            }
        }
        self.refresh_unknown_tracking();
    }

    fn refresh_unknown_tracking(&mut self) {
        if !self.has_unknown_queries() {
            self.unknown_since = None;
        }
    }

    pub fn handle_quick_ack(&mut self, token: u32) {
        let token = token & 0x7fff_ffff;
        if let Some(position) = self.quick_acks.iter().position(|(stored, _)| *stored == token) {
            let (_, ids) = self.quick_acks.remove(position).expect("position is valid");
            for id in ids {
                self.mark_acknowledged(id);
            }
        }
    }

    fn schedule_ack(&mut self, msg_id: i64, now: Now) {
        if self.to_ack.is_empty() {
            self.send_before(now.mono + ACK_DELAY);
        }
        if self.to_ack.last() != Some(&msg_id) {
            self.to_ack.push(msg_id);
            if self.to_ack.len() >= MAX_PENDING_ACKS {
                self.send_before(now.mono);
            }
        }
    }

    pub fn force_ack(&mut self, now: Now) {
        if !self.to_ack.is_empty() {
            self.send_before(now.mono);
        }
    }

    pub fn progress_target(&self, head: &[u8]) -> Option<QueryId> {
        if head.len() < 24 + 48 || read_auth_key_id(head)? != self.auth_key.id() {
            return None;
        }
        let msg_key: [u8; 16] = head[8..24].try_into().ok()?;
        let material = message_key_v2(self.auth_key.bytes(), &msg_key, Side::Server);
        let usable = (head.len() - 24) / 16 * 16;
        let mut plain = head[24..24 + usable].to_vec();
        aes_ige_decrypt(&material.key, &material.iv, &mut plain).ok()?;
        let mut reader = Reader::new(&plain[32..]);
        let mut constructor = reader.read_u32().ok()?;
        if constructor == ids::MSG_CONTAINER {
            reader.read_i32().ok()?;
            reader.skip(16).ok()?;
            constructor = reader.read_u32().ok()?;
        }
        if constructor != ids::RPC_RESULT {
            return None;
        }
        let req_msg_id = reader.read_i64().ok()?;
        self.by_msg_id.get(&req_msg_id).copied()
    }

    pub fn handle_packet(&mut self, packet: &[u8], now: Now, rng: &mut impl SecureRandom) -> Result<(), SessionError> {
        let decrypted = decrypt_message(&self.auth_key, packet, Side::Server)?;
        let header = decrypted.header;
        if header.session_id != self.session_id {
            return Err(SessionError::ForeignSession);
        }
        if header.msg_id & 1 == 0 {
            return Err(SessionError::EvenServerMsgId(header.msg_id));
        }
        self.last_read_at = now.mono;
        self.last_pong_at = now.mono;
        match self.received.check(header.msg_id) {
            DuplicateCheck::New => {}
            DuplicateCheck::Duplicate => {
                self.schedule_ack(header.msg_id, now);
                return Ok(());
            }
            DuplicateCheck::TooOld => return Err(SessionError::TooOld),
        }
        self.observe_server_time(header.msg_id, now);
        if self.time_synchronized {
            let server_time = self.server_time(now);
            let message_time = msg_id_time(header.msg_id);
            if message_time < server_time - MSG_ID_MAX_PAST_SECONDS || message_time > server_time + MSG_ID_MAX_FUTURE_SECONDS {
                self.schedule_ack(header.msg_id, now);
                return Ok(());
            }
        }
        let body = decrypted.body();
        let result = self.process_message(header.msg_id, header.seq_no, body, header.msg_id, now, rng);
        if self.pending_reset {
            self.pending_reset = false;
            self.reset(rng);
            self.send_before(now.mono);
        }
        result?;
        if self.to_ack.len() >= MAX_PENDING_ACKS {
            self.send_before(now.mono);
        }
        Ok(())
    }

    fn observe_server_time(&mut self, msg_id: i64, now: Now) {
        let difference = (msg_id >> 32) as f64 - now.unix;
        if !self.time_synchronized {
            self.time_synchronized = true;
            self.time_difference = difference;
            self.events.push_back(SessionEvent::TimeDifferenceUpdated { difference, forced: false });
        } else if self.time_difference + 1e-4 < difference {
            self.time_difference = difference;
            self.events.push_back(SessionEvent::TimeDifferenceUpdated { difference, forced: false });
        }
    }

    fn reset_server_time(&mut self, msg_id: i64, now: Now) {
        let difference = (msg_id >> 32) as f64 - now.unix;
        self.time_synchronized = false;
        self.time_difference = difference;
        self.events.push_back(SessionEvent::TimeDifferenceUpdated { difference, forced: true });
    }

    fn process_message(
        &mut self,
        msg_id: i64,
        seq_no: i32,
        body: &[u8],
        outer_msg_id: i64,
        now: Now,
        rng: &mut impl SecureRandom,
    ) -> Result<(), SessionError> {
        if seq_no & 1 == 1 {
            self.schedule_ack(msg_id, now);
        }
        if body.len() < 4 {
            return Err(SessionError::Malformed(TlError::UnexpectedEof { offset: 0, needed: 4 }));
        }
        let message = ServiceMessage::parse(body)?;
        match message {
            ServiceMessage::Container(children) => {
                for child in children {
                    if child.msg_id & 1 == 0 {
                        continue;
                    }
                    match self.received.check(child.msg_id) {
                        DuplicateCheck::New => {}
                        DuplicateCheck::Duplicate => {
                            if child.seqno & 1 == 1 {
                                self.schedule_ack(child.msg_id, now);
                            }
                            continue;
                        }
                        DuplicateCheck::TooOld => continue,
                    }
                    if child.body.len() >= 4 && u32::from_le_bytes(child.body[..4].try_into().expect("4")) == ids::MSG_CONTAINER {
                        continue;
                    }
                    self.process_message(child.msg_id, child.seqno, child.body, outer_msg_id, now, rng)?;
                }
            }
            ServiceMessage::GzipPacked(packed) => {
                let unpacked = tlm::gunzip(packed, tlm::MAX_UNPACKED_SIZE)?;
                self.process_message(msg_id, seq_no & !1, &unpacked, outer_msg_id, now, rng)?;
            }
            ServiceMessage::RpcResult { req_msg_id, result } => {
                self.on_rpc_result(msg_id, req_msg_id, result, body.len(), now)?;
            }
            ServiceMessage::Pong { msg_id: ping_msg_id, ping_id } => {
                if msg_id < ping_msg_id.wrapping_sub(15i64 << 32) {
                    self.reset_server_time(msg_id, now);
                }
                self.last_pong_at = now.mono;
                let sent_at = self.pending_pings.remove(&ping_msg_id).or_else(|| self.pending_pings.remove(&ping_id));
                if let Some(sent_at) = sent_at {
                    let rtt = (now.mono - sent_at).max(0.0);
                    self.rtt = if self.rtt == 0.0 { rtt } else { self.rtt * 0.7 + rtt * 0.3 };
                    self.events.push_back(SessionEvent::Pong { rtt });
                }
                if ping_msg_id == self.last_ping_msg_id {
                    self.last_ping_msg_id = 0;
                }
                if self.has_unknown_queries() && now.mono - self.connected_at > 60.0 {
                    return Err(SessionError::UnknownQueriesStuck);
                }
            }
            ServiceMessage::BadServerSalt {
                bad_msg_id,
                new_server_salt,
                ..
            } => {
                let server_time = self.server_time(now);
                self.salts.set_server_salt(new_server_salt, server_time);
                self.events.push_back(SessionEvent::SaltsUpdated { salts: self.salts.all() });
                self.last_future_salts_at = None;
                self.message_failed(bad_msg_id, now);
            }
            ServiceMessage::BadMsgNotification {
                bad_msg_id, error_code, ..
            } => match error_code {
                16 => {
                    self.reset_server_time(msg_id, now);
                    self.message_failed(bad_msg_id, now);
                }
                17 => {
                    self.reset_server_time(msg_id, now);
                    self.message_failed(bad_msg_id, now);
                    self.pending_reset = true;
                }
                32 | 33 | 34 | 35 | 64 => {
                    self.message_failed(bad_msg_id, now);
                    self.pending_reset = true;
                }
                48 => {
                    self.last_future_salts_at = None;
                    self.message_failed(bad_msg_id, now);
                }
                _ => {
                    self.message_failed(bad_msg_id, now);
                }
            },
            ServiceMessage::NewSessionCreated {
                first_msg_id, unique_id, ..
            } => {
                self.on_new_session_created(unique_id, first_msg_id, now);
            }
            ServiceMessage::MsgsAck(msg_ids) => {
                for acked in msg_ids {
                    self.acknowledge(acked);
                }
            }
            ServiceMessage::MsgDetailedInfo {
                msg_id: query_msg_id,
                answer_msg_id,
                status,
                ..
            } => {
                self.on_message_info(Some(query_msg_id), status, Some(answer_msg_id), now);
            }
            ServiceMessage::MsgNewDetailedInfo { answer_msg_id, .. } => {
                self.on_message_info(None, 0, Some(answer_msg_id), now);
            }
            ServiceMessage::MsgsStateInfo { req_msg_id, info } => {
                if let Some(ServiceRequest::StateRequest { msg_ids }) = self.service_requests.remove(&req_msg_id) {
                    self.on_state_info(&msg_ids, info, now);
                }
            }
            ServiceMessage::MsgsAllInfo { msg_ids, info } => {
                self.on_state_info(&msg_ids, info, now);
            }
            ServiceMessage::MsgsStateReq(msg_ids) => {
                let info: Vec<u8> = msg_ids
                    .iter()
                    .map(|id| if self.received.contains(*id) { 4u8 } else { 1u8 })
                    .collect();
                self.to_state_info_reply.push((msg_id, info));
                self.send_before(now.mono);
            }
            ServiceMessage::MsgResendReq(_) => {}
            ServiceMessage::FutureSalts { salts, .. } => {
                self.on_future_salts(&salts, now);
            }
            ServiceMessage::DestroySessionOk { .. } | ServiceMessage::DestroySessionNone { .. } => {}
            ServiceMessage::DestroyAuthKeyOk => self.on_destroy_auth_key(DestroyAuthKeyOutcome::Ok),
            ServiceMessage::DestroyAuthKeyNone => self.on_destroy_auth_key(DestroyAuthKeyOutcome::None),
            ServiceMessage::DestroyAuthKeyFail => self.on_destroy_auth_key(DestroyAuthKeyOutcome::Fail),
            ServiceMessage::Other { constructor, body } => {
                if constructor == ids::PING || constructor == ids::PING_DELAY_DISCONNECT {
                    return Ok(());
                }
                if self.updates.check(msg_id) == DuplicateCheck::New {
                    self.events.push_back(SessionEvent::Update {
                        body: body.to_vec(),
                        msg_id,
                    });
                }
            }
        }
        Ok(())
    }

    fn on_destroy_auth_key(&mut self, outcome: DestroyAuthKeyOutcome) {
        if self.need_destroy_auth_key {
            self.events.push_back(SessionEvent::DestroyAuthKey { outcome });
        }
    }

    fn on_rpc_result(&mut self, msg_id: i64, req_msg_id: i64, result: &[u8], size: usize, now: Now) -> Result<(), SessionError> {
        if msg_id < req_msg_id.wrapping_sub(15i64 << 32) {
            self.reset_server_time(msg_id, now);
        }
        let Some(id) = self.by_msg_id.get(&req_msg_id).copied() else {
            if size > 16 * 1024 {
                self.dropped_answer_bytes += size;
                if self.dropped_answer_bytes > 256 * 1024 {
                    let total = self.dropped_answer_bytes;
                    self.dropped_answer_bytes = 0;
                    self.events.push_back(SessionEvent::DroppedAnswerTooLarge { total });
                }
            }
            return Ok(());
        };
        let event = match tlm::parse_rpc_result(result) {
            Ok(RpcResultBody::Error(error)) => SessionEvent::Error {
                id,
                code: error.code,
                message: error.message,
                response_msg_id: msg_id,
            },
            Ok(RpcResultBody::Value(value)) => SessionEvent::Result {
                id,
                body: value.to_vec(),
                response_msg_id: msg_id,
                original_size: size,
            },
            Ok(RpcResultBody::PackedValue(value)) => SessionEvent::Result {
                id,
                body: value,
                response_msg_id: msg_id,
                original_size: size,
            },
            Ok(RpcResultBody::DropAnswer(_)) => return Ok(()),
            Err(error) => SessionEvent::Error {
                id,
                code: 500,
                message: format!("RESPONSE_UNPACK_FAILED: {error}"),
                response_msg_id: msg_id,
            },
        };
        self.complete_query(id, req_msg_id);
        self.events.push_back(event);
        Ok(())
    }

    fn complete_query(&mut self, id: QueryId, msg_id: i64) {
        if let Some(query) = self.queries.remove(&id) {
            self.by_msg_id.remove(&msg_id);
            if query.container_id != 0 {
                if let Some(children) = self.containers.get_mut(&query.container_id) {
                    children.retain(|child| *child != msg_id);
                    if children.is_empty() {
                        self.containers.remove(&query.container_id);
                    }
                }
            }
        }
        self.refresh_unknown_tracking();
    }

    fn on_new_session_created(&mut self, unique_id: i64, first_msg_id: i64, now: Now) {
        let mut first = first_msg_id;
        if let Some(id) = self.by_msg_id.get(&first_msg_id) {
            if let Some(query) = self.queries.get(id) {
                if query.container_id != 0 {
                    first = query.container_id;
                }
            }
        }
        let mut resend: Vec<(i64, QueryId)> = self
            .queries
            .iter()
            .filter(|(_, query)| query.state != QueryState::Pending)
            .filter(|(_, query)| {
                let reference = if query.container_id != 0 { query.container_id } else { query.msg_id };
                reference < first
            })
            .map(|(id, query)| (query.msg_id, *id))
            .collect();
        resend.sort_unstable();
        for (_, id) in resend {
            self.resend_query(id, now);
        }
        self.events.push_back(SessionEvent::ServerSessionReset {
            unique_id,
            first_msg_id,
        });
    }

    fn on_message_info(&mut self, query_msg_id: Option<i64>, status: i32, answer_msg_id: Option<i64>, now: Now) {
        let query = query_msg_id.and_then(|msg_id| self.by_msg_id.get(&msg_id).copied());
        if let Some(query_msg_id) = query_msg_id {
            let Some(id) = query else {
                if let Some(answer) = answer_msg_id {
                    self.schedule_ack(answer, now);
                }
                return;
            };
            match status & 7 {
                1..=3 => {
                    self.resend_query(id, now);
                    return;
                }
                0 if answer_msg_id.is_none() => {
                    self.resend_query(id, now);
                    return;
                }
                _ => {
                    self.mark_acknowledged(id);
                }
            }
            let _ = query_msg_id;
        }
        if let Some(answer) = answer_msg_id {
            if self.received.contains(answer) {
                self.schedule_ack(answer, now);
            } else {
                if self.to_resend_answer.is_empty() {
                    self.send_before(now.mono + 0.001);
                }
                if !self.to_resend_answer.contains(&answer) {
                    self.to_resend_answer.push(answer);
                }
            }
        }
    }

    fn on_state_info(&mut self, msg_ids: &[i64], info: &[u8], now: Now) {
        if msg_ids.len() != info.len() {
            return;
        }
        for (msg_id, state) in msg_ids.iter().zip(info) {
            if let Some(id) = self.by_msg_id.get(msg_id).copied() {
                match state & 7 {
                    1..=3 => self.resend_query(id, now),
                    4 => self.mark_acknowledged(id),
                    _ => {}
                }
            }
        }
        self.refresh_unknown_tracking();
    }

    fn on_future_salts(&mut self, salts: &[FutureSalt], now: Now) {
        let converted: Vec<ServerSalt> = salts
            .iter()
            .map(|salt| ServerSalt {
                salt: salt.salt,
                valid_since: salt.valid_since as f64,
                valid_until: salt.valid_until as f64,
            })
            .collect();
        let server_time = self.server_time(now);
        self.salts.set_future(converted, server_time);
        self.events.push_back(SessionEvent::SaltsUpdated { salts: self.salts.all() });
    }

    fn may_ping(&self, now: Now) -> bool {
        match self.last_ping_at {
            None => true,
            Some(at) => at + self.ping_may_delay() < now.mono,
        }
    }

    fn must_ping(&self, now: Now) -> bool {
        match self.last_ping_at {
            None => true,
            Some(at) => at + self.ping_must_delay() < now.mono,
        }
    }

    fn must_flush(&mut self, now: Now) -> bool {
        if !self.connected {
            return false;
        }
        let server_time = self.server_time(now);
        let has_salt = self.salts.has_valid_salt(server_time);
        if has_salt {
            if let Some(at) = self.force_send_at {
                if now.mono >= at {
                    return true;
                }
            }
            if self.must_ping(now) {
                return true;
            }
            if self.need_destroy_auth_key && !self.sent_destroy_auth_key {
                return true;
            }
        } else {
            match self.last_future_salts_at {
                None => return true,
                Some(at) if at + FUTURE_SALTS_RETRY < now.mono => return true,
                _ => {}
            }
        }
        false
    }

    pub fn poll_timeout(&mut self, now: Now) -> Option<f64> {
        if !self.connected {
            return None;
        }
        let mut deadline = f64::INFINITY;
        let server_time = self.server_time(now);
        let has_salt = self.salts.has_valid_salt(server_time);
        if has_salt {
            if let Some(at) = self.force_send_at {
                deadline = deadline.min(at);
            }
            match self.last_ping_at {
                Some(at) => deadline = deadline.min(at + self.ping_must_delay()),
                None => deadline = deadline.min(now.mono),
            }
        } else {
            match self.last_future_salts_at {
                Some(at) => deadline = deadline.min(at + FUTURE_SALTS_RETRY),
                None => deadline = deadline.min(now.mono),
            }
        }
        if let Some(change) = self.salts.next_change_time() {
            deadline = deadline.min(now.mono + (change - server_time).max(0.0));
        }
        deadline = deadline.min(self.last_pong_at + self.ping_disconnect_delay() + 0.002);
        deadline = deadline.min(self.last_read_at + self.read_disconnect_delay() + 0.002);
        if let Some(since) = self.unknown_since {
            deadline = deadline.min(since + STATE_REQUEST_RETRY);
        }
        deadline.is_finite().then_some(deadline)
    }

    pub fn handle_timeout(&mut self, now: Now) -> Result<(), SessionError> {
        if !self.connected {
            return Ok(());
        }
        if self.last_pong_at + self.ping_disconnect_delay() < now.mono {
            return Err(SessionError::PingTimeout);
        }
        if self.last_read_at + self.read_disconnect_delay() < now.mono {
            return Err(SessionError::ReadTimeout);
        }
        if let Some(since) = self.unknown_since {
            if since + STATE_REQUEST_RETRY < now.mono {
                self.unknown_since = Some(now.mono);
                let unknown: Vec<i64> = self
                    .queries
                    .values()
                    .filter(|query| query.state == QueryState::Unknown)
                    .map(|query| query.msg_id)
                    .collect();
                let already_requested: Vec<i64> = self
                    .service_requests
                    .values()
                    .flat_map(|request| match request {
                        ServiceRequest::StateRequest { msg_ids } => msg_ids.clone(),
                        ServiceRequest::ResendRequest { .. } => Vec::new(),
                    })
                    .collect();
                for msg_id in unknown {
                    if !already_requested.contains(&msg_id) && !self.to_state_request.contains(&msg_id) {
                        self.to_state_request.push(msg_id);
                    }
                }
                if !self.to_state_request.is_empty() {
                    self.send_before(now.mono);
                }
            }
        }
        Ok(())
    }

    pub fn poll_transmit(&mut self, now: Now, rng: &mut impl SecureRandom) -> Option<Transmit> {
        if !self.must_flush(now) {
            return None;
        }
        self.flush_packet(now, rng)
    }

    fn flush_packet(&mut self, now: Now, rng: &mut impl SecureRandom) -> Option<Transmit> {
        let server_time = self.server_time(now);
        let has_salt = self.salts.has_valid_salt(server_time);

        let mut messages: Vec<OutgoingMessage> = Vec::new();
        let mut query_messages: Vec<(QueryId, usize)> = Vec::new();
        let mut wants_quick_ack = false;

        if has_salt {
            let mut total = 0usize;
            let mut sent_now: HashMap<QueryId, i64> = HashMap::new();
            while let Some(&id) = self.pending.front() {
                if query_messages.len() >= self.config.max_container_queries {
                    break;
                }
                let Some((body_len, invoke_after)) = self.queries.get(&id).map(|query| (query.body.len(), query.options.invoke_after)) else {
                    self.pending.pop_front();
                    continue;
                };
                if !query_messages.is_empty() && total + body_len > self.config.max_container_bytes {
                    break;
                }
                self.pending.pop_front();
                let dependency =
                    invoke_after.and_then(|dependency| sent_now.get(&dependency).copied().or_else(|| self.query_msg_id(dependency)));
                let msg_id = self.next_msg_id(now, rng);
                let seq_no = self.next_seq_no(true);
                let query = self.queries.get_mut(&id).expect("query exists");
                let body = match dependency {
                    Some(after) => {
                        let mut writer = Writer::with_capacity(query.body.len() + 12);
                        tlm::write_invoke_after_msg(&mut writer, after);
                        writer.write_raw(&query.body);
                        writer.into_inner()
                    }
                    None => query.body.clone(),
                };
                total += body.len();
                wants_quick_ack |= query.options.quick_ack;
                query.state = QueryState::Sent;
                query.msg_id = msg_id;
                query.seq_no = seq_no;
                query.sent_at = now.mono;
                query.connection_epoch = self.connection_epoch;
                query.acknowledged = false;
                self.by_msg_id.insert(msg_id, id);
                sent_now.insert(id, msg_id);
                query_messages.push((id, messages.len()));
                messages.push(OutgoingMessage { msg_id, seq_no, body });
            }
        }

        let mut ping_msg_id = 0;
        if has_salt && self.may_ping(now) {
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::with_capacity(20);
            if self.config.use_ping_delay_disconnect {
                tlm::write_ping_delay_disconnect(&mut writer, msg_id, (self.ping_disconnect_delay() + 2.0) as i32);
            } else {
                tlm::write_ping(&mut writer, msg_id);
            }
            self.last_ping_at = Some(now.mono);
            self.pending_pings.insert(msg_id, now.mono);
            ping_msg_id = msg_id;
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
        }

        let mut future_salts_requested = false;
        if self.salts.needs_future_salts(server_time)
            && self.last_future_salts_at.is_none_or(|at| at + FUTURE_SALTS_RETRY < now.mono)
        {
            self.last_future_salts_at = Some(now.mono);
            future_salts_requested = true;
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::with_capacity(8);
            tlm::write_get_future_salts(&mut writer, FUTURE_SALTS_COUNT);
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
        }

        let mut state_request = None;
        if has_salt && !self.to_state_request.is_empty() {
            let ids = take_tail(&mut self.to_state_request, MAX_IDS_PER_SERVICE_MESSAGE);
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::new();
            tlm::write_msgs_state_req(&mut writer, &ids);
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
            state_request = Some((msg_id, ids));
        }

        let mut resend_request = None;
        if has_salt && !self.to_resend_answer.is_empty() {
            let ids = take_tail(&mut self.to_resend_answer, MAX_IDS_PER_SERVICE_MESSAGE);
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::new();
            tlm::write_msg_resend_req(&mut writer, &ids);
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
            resend_request = Some((msg_id, ids));
        }

        if has_salt {
            for msg_id in std::mem::take(&mut self.to_drop_answer) {
                let id = self.next_msg_id(now, rng);
                let seq_no = self.next_seq_no(false);
                let mut writer = Writer::new();
                tlm::write_rpc_drop_answer(&mut writer, msg_id);
                messages.push(OutgoingMessage {
                    msg_id: id,
                    seq_no,
                    body: writer.into_inner(),
                });
            }
            for (req_msg_id, info) in std::mem::take(&mut self.to_state_info_reply) {
                let id = self.next_msg_id(now, rng);
                let seq_no = self.next_seq_no(false);
                let mut writer = Writer::new();
                tlm::write_msgs_state_info(&mut writer, req_msg_id, &info);
                messages.push(OutgoingMessage {
                    msg_id: id,
                    seq_no,
                    body: writer.into_inner(),
                });
            }
        }

        if has_salt && self.need_destroy_auth_key && !self.sent_destroy_auth_key {
            self.sent_destroy_auth_key = true;
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::new();
            tlm::write_destroy_auth_key(&mut writer);
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
        }

        if !self.to_ack.is_empty() {
            let ids = take_tail(&mut self.to_ack, MAX_IDS_PER_SERVICE_MESSAGE);
            let msg_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let mut writer = Writer::with_capacity(16 + ids.len() * 8);
            tlm::write_msgs_ack(&mut writer, &ids);
            messages.push(OutgoingMessage {
                msg_id,
                seq_no,
                body: writer.into_inner(),
            });
        }

        let nothing_left = self.pending.is_empty()
            && self.to_ack.is_empty()
            && self.to_state_request.is_empty()
            && self.to_resend_answer.is_empty()
            && self.to_drop_answer.is_empty()
            && self.to_state_info_reply.is_empty();
        if nothing_left {
            self.force_send_at = None;
        }

        if messages.is_empty() {
            return None;
        }
        let _ = future_salts_requested;

        let (outer_msg_id, seq_no, body, container_id) = if messages.len() == 1 {
            let message = messages.pop().expect("one message");
            (message.msg_id, message.seq_no, message.body, 0)
        } else {
            let container_id = self.next_msg_id(now, rng);
            let seq_no = self.next_seq_no(false);
            let refs: Vec<ContainerMessage<'_>> = messages
                .iter()
                .map(|message| ContainerMessage {
                    msg_id: message.msg_id,
                    seqno: message.seq_no,
                    body: &message.body,
                })
                .collect();
            let total: usize = messages.iter().map(|message| 16 + message.body.len()).sum();
            let mut writer = Writer::with_capacity(8 + total);
            tlm::write_container(&mut writer, &refs);
            (container_id, seq_no, writer.into_inner(), container_id)
        };

        if container_id != 0 {
            let children: Vec<i64> = query_messages.iter().map(|(_, index)| messages[*index].msg_id).collect();
            for (id, _) in &query_messages {
                if let Some(query) = self.queries.get_mut(id) {
                    query.container_id = container_id;
                }
            }
            if !children.is_empty() {
                self.containers.insert(container_id, children);
            }
            let mut services = Vec::new();
            if let Some((msg_id, _)) = &state_request {
                services.push(*msg_id);
            }
            if let Some((msg_id, _)) = &resend_request {
                services.push(*msg_id);
            }
            if ping_msg_id != 0 {
                services.push(ping_msg_id);
                self.last_ping_container_id = container_id;
            }
            if !services.is_empty() {
                self.service_containers.insert(container_id, services);
            }
        }
        if ping_msg_id != 0 {
            self.last_ping_msg_id = ping_msg_id;
        }
        if let Some((msg_id, ids)) = state_request {
            self.service_requests.insert(msg_id, ServiceRequest::StateRequest { msg_ids: ids });
        }
        if let Some((msg_id, ids)) = resend_request {
            self.service_requests.insert(msg_id, ServiceRequest::ResendRequest { msg_ids: ids });
        }

        let header = MessageHeader {
            salt: self.salts.current_salt(server_time),
            session_id: self.session_id,
            msg_id: outer_msg_id,
            seq_no,
        };
        let packet = encrypt_message(&self.auth_key, &header, &body, Side::Client, self.config.padding, rng);
        let quick_ack_token = if wants_quick_ack {
            let token = packet.quick_ack_token & 0x7fff_ffff;
            let ids: Vec<QueryId> = query_messages
                .iter()
                .filter(|(id, _)| self.queries.get(id).is_some_and(|query| query.options.quick_ack))
                .map(|(id, _)| *id)
                .collect();
            self.quick_acks.push_back((token, ids));
            while self.quick_acks.len() > MAX_RECENT_QUICK_ACKS {
                self.quick_acks.pop_front();
            }
            Some(packet.quick_ack_token)
        } else {
            None
        };
        Some(Transmit {
            data: packet.data,
            quick_ack_token,
            msg_id: outer_msg_id,
            contains_queries: !query_messages.is_empty(),
        })
    }

    pub fn poll_event(&mut self) -> Option<SessionEvent> {
        self.events.pop_front()
    }

    pub fn drain_events(&mut self) -> Vec<SessionEvent> {
        self.events.drain(..).collect()
    }

    pub fn shrink(&mut self) {
        if self.queries.is_empty() {
            self.queries.shrink_to(16);
            self.by_msg_id.shrink_to(16);
            self.pending.shrink_to(16);
            self.containers.shrink_to(16);
        }
    }
}

struct OutgoingMessage {
    msg_id: i64,
    seq_no: i32,
    body: Vec<u8>,
}

fn take_tail(source: &mut Vec<i64>, limit: usize) -> Vec<i64> {
    if source.len() <= limit {
        return std::mem::take(source);
    }
    let split = source.len() - limit;
    source.split_off(split)
}

#[cfg(test)]
mod tests;
