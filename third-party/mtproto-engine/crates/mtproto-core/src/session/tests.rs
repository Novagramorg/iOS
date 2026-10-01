use super::*;
use crate::crypto::XorShiftRandom;
use crate::test_support::server_peer::*;

const START: f64 = 1_727_000_000.0;
const QUERY_CONSTRUCTOR: u32 = 0x1122_3344;

struct Harness {
    session: Session,
    server: ServerPeer,
    rng: XorShiftRandom,
    now: Now,
}

fn key() -> AuthKey {
    AuthKey::new(core::array::from_fn(|i| (i as u8).wrapping_mul(29).wrapping_add(7)))
}

fn query_body(tag: u32) -> Vec<u8> {
    let mut writer = Writer::new();
    writer.write_u32(QUERY_CONSTRUCTOR);
    writer.write_u32(tag);
    writer.into_inner()
}

fn query_tag(body: &[u8]) -> Option<u32> {
    let mut reader = Reader::new(body);
    let mut constructor = reader.read_u32().ok()?;
    if constructor == ids::INVOKE_AFTER_MSG {
        reader.read_i64().ok()?;
        constructor = reader.read_u32().ok()?;
    }
    (constructor == QUERY_CONSTRUCTOR).then(|| reader.read_u32().ok()).flatten()
}

impl Harness {
    fn new() -> Self {
        Self::with_salts(vec![
            ServerSalt {
                salt: 101,
                valid_since: START - 100.0,
                valid_until: START + 1800.0,
            },
            ServerSalt {
                salt: 102,
                valid_since: START + 1800.0,
                valid_until: START + 3600.0,
            },
        ])
    }

    fn with_salts(salts: Vec<ServerSalt>) -> Self {
        let mut rng = XorShiftRandom::new(5);
        let now = Now { mono: 100.0, unix: START };
        let mut session = Session::new(SessionConfig::default(), key(), &salts, 0.0, now, &mut rng);
        session.connection_opened(now);
        let mut server = ServerPeer::new(key(), START);
        server.salt = 101;
        Self { session, server, rng, now }
    }

    fn advance(&mut self, seconds: f64) {
        self.now.mono += seconds;
        self.now.unix += seconds;
        self.server.server_time += seconds;
    }

    fn flush(&mut self) -> Option<DecodedPacket> {
        self.advance(0.002);
        let transmit = self.session.poll_transmit(self.now, &mut self.rng)?;
        Some(self.server.decode(&transmit.data))
    }

    fn flush_all(&mut self) -> Vec<DecodedPacket> {
        let mut packets = Vec::new();
        while let Some(packet) = self.flush() {
            packets.push(packet);
            if packets.len() > 50 {
                panic!("flush loop");
            }
        }
        packets
    }

    fn deliver(&mut self, items: Vec<Outgoing>) -> Result<(), SessionError> {
        let packet = self.server.encode(items);
        self.session.handle_packet(&packet, self.now, &mut self.rng)
    }

    fn events(&mut self) -> Vec<SessionEvent> {
        self.session.drain_events()
    }

    fn results(&mut self) -> Vec<(QueryId, Vec<u8>)> {
        self.events()
            .into_iter()
            .filter_map(|event| match event {
                SessionEvent::Result { id, body, .. } => Some((id, body)),
                _ => None,
            })
            .collect()
    }

    fn sent_query(&mut self, packet: &DecodedPacket, tag: u32) -> i64 {
        packet
            .messages
            .iter()
            .find(|message| query_tag(&message.body) == Some(tag))
            .map(|message| message.msg_id)
            .unwrap_or_else(|| panic!("query {tag} not in packet {:x?}", packet.constructors()))
    }
}

#[test]
fn request_roundtrip_with_ping_and_acks() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().expect("packet");
    assert_eq!(packet.header.salt, 101);
    assert!(packet.find(ids::PING_DELAY_DISCONNECT).is_some());
    let query_msg_id = h.sent_query(&packet, 1);
    assert_eq!(query_msg_id % 4, 0);
    let query = packet.messages.iter().find(|m| m.msg_id == query_msg_id).unwrap();
    assert!(query.is_content_related());
    let ping = packet.find(ids::PING_DELAY_DISCONNECT).unwrap();
    assert!(!ping.is_content_related());
    assert!(packet.messages.iter().all(|m| m.msg_id < packet.header.msg_id));

    h.deliver(vec![Outgoing::Content(rpc_result(query_msg_id, &[1, 2, 3, 4]))]).unwrap();
    assert_eq!(h.results(), vec![(QueryId(1), vec![1, 2, 3, 4])]);
    assert!(!h.session.has_queries());

    assert!(h.flush().is_none(), "acks are delayed");
    h.advance(ACK_DELAY + 1.0);
    let packet = h.flush().expect("ack packet");
    let ack = packet.find(ids::MSGS_ACK).expect("ack");
    assert_eq!(read_vector_after_constructor(&ack.body).len(), 1);
}

#[test]
fn queries_are_packed_into_one_container_in_order() {
    let mut h = Harness::new();
    for tag in 1..=5 {
        h.session.send(QueryId(tag as u64), query_body(tag), QueryOptions::default(), h.now);
    }
    let packet = h.flush().unwrap();
    let tags: Vec<u32> = packet.messages.iter().filter_map(|m| query_tag(&m.body)).collect();
    assert_eq!(tags, vec![1, 2, 3, 4, 5]);
    let ids: Vec<i64> = packet.queries().iter().map(|m| m.msg_id).collect();
    assert!(ids.windows(2).all(|w| w[0] < w[1]));
    let seqs: Vec<i32> = packet.queries().iter().map(|m| m.seq_no).collect();
    assert_eq!(seqs, vec![1, 3, 5, 7, 9]);
}

#[test]
fn container_limits_split_packets() {
    let mut h = Harness::new();
    for tag in 0..40u32 {
        let mut body = query_body(tag);
        body.extend(vec![0u8; 2048]);
        h.session.send(QueryId(tag as u64), body, QueryOptions::default(), h.now);
    }
    let packets = h.flush_all();
    assert!(packets.len() >= 3, "{}", packets.len());
    let total: usize = packets.iter().map(|p| p.queries().len()).sum();
    assert_eq!(total, 40);
    for packet in &packets {
        let size: usize = packet.queries().iter().map(|m| m.body.len()).sum();
        assert!(size <= DEFAULT_CONTAINER_BYTES + 2100);
    }
}

#[test]
fn single_large_query_is_sent_alone() {
    let mut h = Harness::new();
    h.session.set_online(false, h.now);
    let mut warmup = h.flush_all();
    warmup.clear();
    let mut body = query_body(9);
    body.extend(vec![1u8; 600 * 1024]);
    h.session.send(QueryId(9), body.clone(), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    assert_eq!(packet.messages.len(), 1);
    assert_eq!(packet.messages[0].body, body);
}

#[test]
fn bad_server_salt_updates_salt_and_resends() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first_id = h.sent_query(&packet, 1);
    h.deliver(vec![Outgoing::Service(bad_server_salt(packet.header.msg_id, packet.header.seq_no, 555))]).unwrap();
    let events = h.events();
    assert!(events.iter().any(|e| matches!(e, SessionEvent::SaltsUpdated { .. })));
    let packet = h.flush().unwrap();
    assert_eq!(packet.header.salt, 555);
    let second_id = h.sent_query(&packet, 1);
    assert!(second_id > first_id);
    assert!(packet.find(ids::GET_FUTURE_SALTS).is_some());
}

#[test]
fn bad_msg_16_resyncs_time_and_resends() {
    let mut h = Harness::new();
    h.server.server_time += 500.0;
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first_id = h.sent_query(&packet, 1);
    h.deliver(vec![Outgoing::Service(bad_msg_notification(first_id, 1, 16))]).unwrap();
    let events = h.events();
    assert!(events
        .iter()
        .any(|e| matches!(e, SessionEvent::TimeDifferenceUpdated { forced: true, difference } if (*difference - 500.0).abs() < 1.0)));
    let packet = h.flush().unwrap();
    let second_id = h.sent_query(&packet, 1);
    assert!(msg_id_time(second_id) > START + 499.0);
}

#[test]
fn bad_msg_17_resets_session() {
    let mut h = Harness::new();
    let old_session = h.session.session_id();
    h.server.server_time -= 300.0;
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first_id = h.sent_query(&packet, 1);
    h.deliver(vec![Outgoing::Service(bad_msg_notification(first_id, 1, 17))]).unwrap();
    let events = h.events();
    assert!(events.iter().any(|e| matches!(e, SessionEvent::LocalSessionReset { .. })));
    assert_ne!(h.session.session_id(), old_session);
    let packet = h.flush().unwrap();
    let second_id = h.sent_query(&packet, 1);
    assert!(msg_id_time(second_id) < START - 299.0);
    assert_eq!(packet.header.session_id, h.session.session_id());
}

#[test]
fn bad_msg_32_resets_session_and_keeps_processing_container() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let second = h.sent_query(&packet, 2);
    h.deliver(vec![
        Outgoing::Content(rpc_result(first, &[9, 9, 9, 9])),
        Outgoing::Service(bad_msg_notification(second, 3, 32)),
    ])
    .unwrap();
    let events = h.events();
    assert!(events.iter().any(|e| matches!(e, SessionEvent::Result { id: QueryId(1), .. })));
    assert!(events.iter().any(|e| matches!(e, SessionEvent::LocalSessionReset { .. })));
    let packet = h.flush().unwrap();
    assert_eq!(packet.messages.iter().filter_map(|m| query_tag(&m.body)).collect::<Vec<_>>(), vec![2]);
    assert_eq!(packet.queries()[0].seq_no, 1);
}

#[test]
fn new_session_created_resends_older_queries_and_reports_reset() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let first_packet = h.flush().unwrap();
    let first = h.sent_query(&first_packet, 1);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let second_packet = h.flush().unwrap();
    let second = h.sent_query(&second_packet, 2);
    h.deliver(vec![Outgoing::Content(new_session_created(second, 42, 101))]).unwrap();
    let events = h.events();
    assert!(events
        .iter()
        .any(|e| matches!(e, SessionEvent::ServerSessionReset { unique_id: 42, .. })));
    let packet = h.flush().unwrap();
    let tags: Vec<u32> = packet.messages.iter().filter_map(|m| query_tag(&m.body)).collect();
    assert_eq!(tags, vec![1]);
    assert!(h.sent_query(&packet, 1) > first);
    h.deliver(vec![Outgoing::Content(rpc_result(second, &[2, 0, 0, 0]))]).unwrap();
    assert_eq!(h.results(), vec![(QueryId(2), vec![2, 0, 0, 0])]);
}

#[test]
fn reconnect_without_ack_asks_state_and_resends_only_unreceived() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let second = h.sent_query(&packet, 2);
    h.session.connection_closed();
    assert!(h.session.has_unknown_queries());
    assert!(h.session.is_performing_service_tasks());
    h.advance(1.0);
    h.session.connection_opened(h.now);
    let packet = h.flush().unwrap();
    assert!(packet.messages.iter().all(|m| query_tag(&m.body).is_none()), "no blind resend");
    let state_request = packet.find(ids::MSGS_STATE_REQ).expect("state request");
    let mut asked = read_vector_after_constructor(&state_request.body);
    asked.sort_unstable();
    assert_eq!(asked, vec![first, second]);
    let info: Vec<u8> = read_vector_after_constructor(&state_request.body)
        .iter()
        .map(|id| if *id == first { 4 } else { 2 })
        .collect();
    h.deliver(vec![Outgoing::Content(msgs_state_info(state_request.msg_id, &info))]).unwrap();
    let events = h.events();
    assert!(events.iter().any(|e| matches!(e, SessionEvent::Acknowledged { id: QueryId(1) })));
    assert!(!h.session.has_unknown_queries());
    let packet = h.flush().unwrap();
    let tags: Vec<u32> = packet.messages.iter().filter_map(|m| query_tag(&m.body)).collect();
    assert_eq!(tags, vec![2]);
    h.deliver(vec![Outgoing::Content(rpc_result(first, &[1, 1, 1, 1]))]).unwrap();
    assert_eq!(h.results(), vec![(QueryId(1), vec![1, 1, 1, 1])]);
}

#[test]
fn acknowledged_queries_survive_reconnect_without_state_request() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    h.deliver(vec![Outgoing::Service(msgs_ack(&[packet.header.msg_id]))]).unwrap();
    assert!(h.events().iter().any(|e| matches!(e, SessionEvent::Acknowledged { id: QueryId(1) })));
    h.session.connection_closed();
    h.session.connection_opened(h.now);
    assert!(!h.session.has_unknown_queries());
    let packets = h.flush_all();
    for packet in &packets {
        assert!(packet.find(ids::MSGS_STATE_REQ).is_none());
        assert!(packet.messages.iter().all(|m| query_tag(&m.body).is_none()));
    }
    h.deliver(vec![Outgoing::Content(rpc_result(first, &[7, 7, 7, 7]))]).unwrap();
    assert_eq!(h.results().len(), 1);
}

#[test]
fn unanswered_state_request_is_retried() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.flush().unwrap();
    h.session.connection_closed();
    h.session.connection_opened(h.now);
    let packet = h.flush().unwrap();
    assert!(packet.find(ids::MSGS_STATE_REQ).is_some());
    h.deliver(vec![Outgoing::Service(pong(packet.header.msg_id, 0))]).unwrap();
    h.advance(STATE_REQUEST_RETRY - 1.0);
    h.session.handle_timeout(h.now).unwrap();
    assert!(h.flush().map_or(true, |p| p.find(ids::MSGS_STATE_REQ).is_none()));
}

#[test]
fn quick_ack_marks_query_acknowledged() {
    let mut h = Harness::new();
    h.session.send(
        QueryId(7),
        query_body(7),
        QueryOptions {
            quick_ack: true,
            invoke_after: None,
        },
        h.now,
    );
    h.advance(0.01);
    let transmit = h.session.poll_transmit(h.now, &mut h.rng).unwrap();
    let token = transmit.quick_ack_token.expect("quick ack requested");
    h.session.handle_quick_ack(token | 0x8000_0000);
    assert_eq!(h.events(), vec![SessionEvent::Acknowledged { id: QueryId(7) }]);
    h.session.handle_quick_ack(token);
    assert!(h.events().is_empty());
}

#[test]
fn msgs_ack_on_container_acknowledges_children_once() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    h.deliver(vec![Outgoing::Service(msgs_ack(&[packet.header.msg_id, packet.header.msg_id]))]).unwrap();
    let acks: Vec<SessionEvent> = h
        .events()
        .into_iter()
        .filter(|e| matches!(e, SessionEvent::Acknowledged { .. }))
        .collect();
    assert_eq!(acks.len(), 2);
}

#[test]
fn gzip_rpc_errors_and_duplicates() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let second = h.sent_query(&packet, 2);
    let big = vec![5u8; 100_000];
    let packet = h.server.encode(vec![
        Outgoing::Content(rpc_result_gzipped(first, &big)),
        Outgoing::Content(rpc_error(second, 420, "FLOOD_WAIT_7")),
    ]);
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    let events = h.events();
    let results: Vec<&SessionEvent> = events.iter().filter(|e| matches!(e, SessionEvent::Result { .. })).collect();
    assert_eq!(results.len(), 1);
    match results[0] {
        SessionEvent::Result { id, body, .. } => {
            assert_eq!(*id, QueryId(1));
            assert_eq!(body, &big);
        }
        _ => unreachable!(),
    }
    assert!(events.iter().any(|e| matches!(e, SessionEvent::Error { id: QueryId(2), code: 420, message, .. } if message == "FLOOD_WAIT_7")));
}

#[test]
fn updates_are_delivered_once_and_unknown_constructors_do_not_break_containers() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let update_msg_id = h.server.next_msg_id(false);
    let updates = update(0x74ae4240, &[1, 2, 3, 4]);
    let packet = h.server.encode(vec![
        Outgoing::Raw {
            body: updates.clone(),
            seq_no: 1,
            msg_id: Some(update_msg_id),
        },
        Outgoing::Content(update(0xdeadbeef, &[0; 8])),
        Outgoing::Content(rpc_result(first, &[3, 3, 3, 3])),
    ]);
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    let events = h.events();
    let update_events: Vec<&SessionEvent> = events.iter().filter(|e| matches!(e, SessionEvent::Update { .. })).collect();
    assert_eq!(update_events.len(), 2);
    assert!(events.iter().any(|e| matches!(e, SessionEvent::Result { id: QueryId(1), .. })));
    let resent = h.server.seal(update_msg_id, 1, &updates);
    h.session.handle_packet(&resent, h.now, &mut h.rng).unwrap();
    assert!(h.events().iter().all(|e| !matches!(e, SessionEvent::Update { .. })));
}

#[test]
fn missing_salt_requests_future_salts_first() {
    let mut h = Harness::with_salts(vec![]);
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    assert_eq!(packet.constructors(), vec![ids::GET_FUTURE_SALTS]);
    assert!(h.flush().is_none());
    let request = packet.messages[0].msg_id;
    let now = h.server.server_time as i32;
    h.deliver(vec![
        Outgoing::Service(bad_server_salt(request, 0, 900)),
        Outgoing::Content(future_salts(request, now, &[(now - 10, now + 1800, 900), (now + 1800, now + 3600, 901)])),
    ])
    .unwrap();
    let packet = h.flush().unwrap();
    assert_eq!(packet.header.salt, 900);
    h.sent_query(&packet, 1);
    h.advance(1900.0);
    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    assert_eq!(packet.header.salt, 901);
}

#[test]
fn msg_detailed_info_requests_lost_answer() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let answer_id = h.server.next_msg_id(true);
    h.deliver(vec![Outgoing::Service(msg_detailed_info(first, answer_id, 1000))]).unwrap();
    assert!(h.events().iter().any(|e| matches!(e, SessionEvent::Acknowledged { id: QueryId(1) })));
    let packet = h.flush().unwrap();
    let resend = packet.find(ids::MSG_RESEND_REQ).expect("resend request");
    assert_eq!(read_vector_after_constructor(&resend.body), vec![answer_id]);
    let answer = h.server.seal(answer_id, 1, &rpc_result(first, &[4, 4, 4, 4]));
    h.session.handle_packet(&answer, h.now, &mut h.rng).unwrap();
    assert_eq!(h.results(), vec![(QueryId(1), vec![4, 4, 4, 4])]);
}

#[test]
fn msg_new_detailed_info_for_received_message_is_only_acked() {
    let mut h = Harness::new();
    h.flush();
    let update_id = h.server.next_msg_id(false);
    let packet = h.server.seal(update_id, 1, &update(0x1234_5678, &[0; 4]));
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    h.events();
    h.deliver(vec![Outgoing::Service(msg_new_detailed_info(update_id, 100))]).unwrap();
    h.advance(ACK_DELAY + 1.0);
    let packets = h.flush_all();
    assert!(packets.iter().all(|p| p.find(ids::MSG_RESEND_REQ).is_none()));
    assert!(packets.iter().any(|p| p.find(ids::MSGS_ACK).is_some()));
}

#[test]
fn dependencies_wrap_invoke_after_msg() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    h.session.send(
        QueryId(2),
        query_body(2),
        QueryOptions {
            quick_ack: false,
            invoke_after: Some(QueryId(1)),
        },
        h.now,
    );
    let packet = h.flush().unwrap();
    let first = h.sent_query(&packet, 1);
    let dependent = packet.messages.iter().find(|m| query_tag(&m.body) == Some(2)).unwrap();
    let mut reader = Reader::new(&dependent.body);
    assert_eq!(reader.read_u32().unwrap(), ids::INVOKE_AFTER_MSG);
    assert_eq!(reader.read_i64().unwrap(), first);

    h.deliver(vec![Outgoing::Content(rpc_result(first, &[0; 4]))]).unwrap();
    h.session.send(
        QueryId(3),
        query_body(3),
        QueryOptions {
            quick_ack: false,
            invoke_after: Some(QueryId(1)),
        },
        h.now,
    );
    let packet = h.flush().unwrap();
    let third = packet.messages.iter().find(|m| query_tag(&m.body) == Some(3)).unwrap();
    assert_eq!(u32::from_le_bytes(third.body[..4].try_into().unwrap()), QUERY_CONSTRUCTOR);
}

#[test]
fn cancellation() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    assert_eq!(h.session.cancel(QueryId(1)), CancelOutcome::Removed);
    let packets = h.flush_all();
    assert!(packets.iter().all(|p| p.messages.iter().all(|m| query_tag(&m.body).is_none())));

    h.session.send(QueryId(2), query_body(2), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let second = h.sent_query(&packet, 2);
    assert_eq!(h.session.cancel(QueryId(2)), CancelOutcome::RemovedInFlight { msg_id: second });
    h.deliver(vec![Outgoing::Content(rpc_result(second, &[0; 4]))]).unwrap();
    assert!(h.results().is_empty());
    assert_eq!(h.session.cancel(QueryId(2)), CancelOutcome::NotFound);
}

#[test]
fn ping_and_read_timeouts() {
    let mut h = Harness::new();
    h.flush_all();
    let deadline = h.session.poll_timeout(h.now).unwrap();
    assert!(deadline > h.now.mono);
    h.advance(200.0);
    assert!(matches!(h.session.handle_timeout(h.now), Err(SessionError::PingTimeout) | Err(SessionError::ReadTimeout)));
}

#[test]
fn online_mode_pings_faster() {
    let mut h = Harness::new();
    h.session.set_online(true, h.now);
    h.flush_all();
    h.advance(3.0);
    let packet = h.flush().expect("ping due");
    assert!(packet.find(ids::PING_DELAY_DISCONNECT).is_some());
}

#[test]
fn foreign_session_and_tampering_are_rejected() {
    let mut h = Harness::new();
    h.flush();
    let mut other = ServerPeer::new(key(), START);
    other.session_id = h.session.session_id() ^ 1;
    let packet = other.encode(vec![Outgoing::Content(update(1, &[0; 4]))]);
    assert_eq!(h.session.handle_packet(&packet, h.now, &mut h.rng), Err(SessionError::ForeignSession));
    let mut packet = h.server.encode(vec![Outgoing::Content(update(1, &[0; 4]))]);
    let last = packet.len() - 1;
    packet[last] ^= 1;
    assert!(matches!(h.session.handle_packet(&packet, h.now, &mut h.rng), Err(SessionError::Decrypt(_))));
}

#[test]
fn messages_outside_time_window_are_ignored_after_sync() {
    let mut h = Harness::new();
    h.flush();
    h.deliver(vec![Outgoing::Content(update(1, &[0; 4]))]).unwrap();
    h.events();
    let old_id = msg_id_for_time(START - 400.0) | 3;
    let packet = h.server.seal(old_id, 1, &update(2, &[0; 4]));
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    assert!(h.events().iter().all(|e| !matches!(e, SessionEvent::Update { .. })));
}

#[test]
fn server_state_request_is_answered() {
    let mut h = Harness::new();
    h.flush();
    let update_id = h.server.next_msg_id(false);
    let packet = h.server.seal(update_id, 1, &update(5, &[0; 4]));
    h.session.handle_packet(&packet, h.now, &mut h.rng).unwrap();
    let unknown_id = update_id + 400;
    h.deliver(vec![Outgoing::Content(msgs_state_req(&[update_id, unknown_id]))]).unwrap();
    let packet = h.flush().unwrap();
    let reply = packet.find(ids::MSGS_STATE_INFO).expect("state info reply");
    let mut reader = Reader::new(&reply.body[4..]);
    reader.read_i64().unwrap();
    assert_eq!(reader.read_bytes().unwrap(), &[4, 1]);
}

#[test]
fn progress_target_identifies_large_result() {
    let mut h = Harness::new();
    h.session.send(QueryId(77), query_body(77), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let msg_id = h.sent_query(&packet, 77);
    let big = vec![9u8; 4096];
    let response = h.server.encode(vec![Outgoing::Content(rpc_result(msg_id, &big))]);
    assert_eq!(h.session.progress_target(&response[..128]), Some(QueryId(77)));
    let container = h.server.encode(vec![
        Outgoing::Content(rpc_result(msg_id, &big)),
        Outgoing::Content(update(1, &[0; 4])),
    ]);
    assert_eq!(h.session.progress_target(&container[..128]), Some(QueryId(77)));
    assert_eq!(h.session.progress_target(&response[..40]), None);
}

#[test]
fn reset_requeues_everything_in_original_order() {
    let mut h = Harness::new();
    for tag in 1..=3 {
        h.session.send(QueryId(tag), query_body(tag as u32), QueryOptions::default(), h.now);
    }
    h.flush().unwrap();
    h.session.send(QueryId(4), query_body(4), QueryOptions::default(), h.now);
    h.session.reset(&mut h.rng);
    let packet = h.flush().unwrap();
    let tags: Vec<u32> = packet.messages.iter().filter_map(|m| query_tag(&m.body)).collect();
    assert_eq!(tags, vec![1, 2, 3, 4]);
}

#[test]
fn many_acks_flush_immediately() {
    let mut h = Harness::new();
    h.flush_all();
    for _ in 0..MAX_PENDING_ACKS {
        h.deliver(vec![Outgoing::Content(update(9, &[0; 4]))]).unwrap();
    }
    let packet = h.flush().expect("ack flush");
    let ack = packet.find(ids::MSGS_ACK).unwrap();
    assert_eq!(read_vector_after_constructor(&ack.body).len(), MAX_PENDING_ACKS);
}

#[test]
fn dropped_answers_are_accounted() {
    let mut h = Harness::new();
    h.session.send(QueryId(1), query_body(1), QueryOptions::default(), h.now);
    let packet = h.flush().unwrap();
    let msg_id = h.sent_query(&packet, 1);
    h.session.cancel(QueryId(1));
    for _ in 0..20 {
        h.deliver(vec![Outgoing::Content(rpc_result(msg_id, &vec![0u8; 20_000]))]).unwrap();
    }
    assert!(h.events().iter().any(|e| matches!(e, SessionEvent::DroppedAnswerTooLarge { .. })));
}
