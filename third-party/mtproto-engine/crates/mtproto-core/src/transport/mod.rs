mod buffer;
mod codec;
mod obfuscation;
mod proxy_secret;
mod socks5;
mod stream;
mod tls;

pub use buffer::InputBuffer;
pub use codec::{
    FrameDecoder, Framing, Incoming, MAX_FRAME_LEN, SHORT_FRAME_LEN, SHORT_PADDED_FRAME_LEN, encode_frame,
    trim_padded_payload,
};
pub use obfuscation::{
    OBFUSCATED_HEADER_LEN, ObfuscatedInit, ServerObfuscation, accept_obfuscated_header, obfuscated_init,
};
pub use proxy_secret::{MAX_DOMAIN_LENGTH, ProxySecret, ProxySecretError};
pub use socks5::{Socks5Auth, Socks5Error, Socks5Handshake, Socks5Progress, Socks5Target};
pub use stream::{TransportConfig, TransportStream};
pub use tls::{
    MAX_TLS_PACKET_LENGTH, MIN_CLIENT_HELLO_LEN, TlsHelloError, TlsRecordReader, TlsRecordWriter, client_hello,
    server_hello_for_tests, verify_client_hello_for_tests, verify_server_hello,
};

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TransportError {
    #[error("invalid frame length {0}")]
    InvalidLength(u64),
    #[error("invalid abridged length marker {0:#04x}")]
    InvalidMarker(u8),
    #[error("tls: {0}")]
    Tls(#[from] TlsHelloError),
    #[error("invalid tls record header")]
    InvalidTlsRecord,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportErrorKind {
    AuthKeyNotFound,
    Flood,
    InvalidDc,
    Forbidden,
    Other,
}

impl TransportErrorKind {
    pub fn from_code(code: i32) -> Self {
        match code {
            -404 => TransportErrorKind::AuthKeyNotFound,
            -429 => TransportErrorKind::Flood,
            -444 => TransportErrorKind::InvalidDc,
            -403 => TransportErrorKind::Forbidden,
            _ => TransportErrorKind::Other,
        }
    }

    pub fn request_was_rejected(self) -> bool {
        matches!(self, TransportErrorKind::Flood | TransportErrorKind::InvalidDc)
    }
}

pub const TRANSPORT_FLOOD_DELAY: f64 = 1.0;
pub const TRANSPORT_FLOOD_MAX_DELAY: f64 = 30.0;
pub const RECONNECT_DELAYS: [f64; 5] = [0.0, 0.3, 1.0, 2.0, 4.0];
pub const URGENT_RECONNECT_DELAYS: [f64; 4] = [0.0, 0.05, 0.1, 0.25];
pub const RECONNECT_JITTER: f64 = 0.2;

pub fn transport_flood_delay(consecutive: u32) -> f64 {
    let exponent = consecutive.saturating_sub(1).min(16);
    (TRANSPORT_FLOOD_DELAY * f64::from(1u32 << exponent)).min(TRANSPORT_FLOOD_MAX_DELAY)
}

pub fn urgent_reconnect_delay(failures: u32, random: u32) -> f64 {
    if failures == 0 {
        return 0.0;
    }
    let index = (failures as usize - 1).min(URGENT_RECONNECT_DELAYS.len() - 1);
    let unit = f64::from(random) / f64::from(u32::MAX);
    URGENT_RECONNECT_DELAYS[index] * (1.0 + RECONNECT_JITTER * (2.0 * unit - 1.0))
}

pub fn reconnect_delay(failures: u32, random: u32) -> f64 {
    if failures == 0 {
        return 0.0;
    }
    let index = (failures as usize - 1).min(RECONNECT_DELAYS.len() - 1);
    let base = RECONNECT_DELAYS[index];
    let unit = f64::from(random) / f64::from(u32::MAX);
    base * (1.0 + RECONNECT_JITTER * (2.0 * unit - 1.0))
}

#[cfg(test)]
mod policy_tests {
    use super::*;

    #[test]
    fn transport_error_kinds() {
        assert_eq!(TransportErrorKind::from_code(-404), TransportErrorKind::AuthKeyNotFound);
        assert_eq!(TransportErrorKind::from_code(-429), TransportErrorKind::Flood);
        assert_eq!(TransportErrorKind::from_code(-444), TransportErrorKind::InvalidDc);
        assert_eq!(TransportErrorKind::from_code(-403), TransportErrorKind::Forbidden);
        assert_eq!(TransportErrorKind::from_code(-1), TransportErrorKind::Other);
        assert_eq!(TransportErrorKind::from_code(7), TransportErrorKind::Other);
        assert!(TransportErrorKind::Flood.request_was_rejected());
        assert!(TransportErrorKind::InvalidDc.request_was_rejected());
        assert!(!TransportErrorKind::AuthKeyNotFound.request_was_rejected());
        assert!(!TransportErrorKind::Other.request_was_rejected());
    }

    #[test]
    fn flood_delay_grows_and_caps() {
        let delays: Vec<f64> = (1..=7).map(transport_flood_delay).collect();
        assert_eq!(delays, vec![1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 30.0]);
        assert_eq!(transport_flood_delay(0), 1.0);
        assert_eq!(transport_flood_delay(u32::MAX), 30.0);
    }

    #[test]
    fn urgent_ladder_retries_four_times_a_second_at_most() {
        assert_eq!(urgent_reconnect_delay(0, 0), 0.0);
        assert_eq!(urgent_reconnect_delay(1, u32::MAX / 2), 0.0);
        for failures in 4..40 {
            let delay = urgent_reconnect_delay(failures, u32::MAX);
            assert!((0.2..=0.3).contains(&delay), "{failures}: {delay}");
        }
    }

    #[test]
    fn reconnect_ladder_is_fast_and_jittered() {
        assert_eq!(reconnect_delay(0, u32::MAX), 0.0);
        assert_eq!(reconnect_delay(1, u32::MAX), 0.0);
        for (failures, base) in [(2u32, 0.3), (3, 1.0), (4, 2.0), (5, 4.0), (50, 4.0)] {
            let low = reconnect_delay(failures, 0);
            let mid = reconnect_delay(failures, u32::MAX / 2);
            let high = reconnect_delay(failures, u32::MAX);
            assert!((low - base * 0.8).abs() < 1e-9, "{failures}");
            assert!((mid - base).abs() < 1e-6, "{failures}");
            assert!((high - base * 1.2).abs() < 1e-9, "{failures}");
        }
    }
}
