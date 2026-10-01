mod buffer;
mod codec;
mod obfuscation;
mod proxy_secret;
mod socks5;
mod stream;
mod tls;

pub use buffer::InputBuffer;
pub use codec::{encode_frame, trim_padded_payload, FrameDecoder, Framing, Incoming, MAX_FRAME_LEN};
pub use obfuscation::{accept_obfuscated_header, obfuscated_init, ObfuscatedInit, ServerObfuscation, OBFUSCATED_HEADER_LEN};
pub use proxy_secret::{ProxySecret, ProxySecretError, MAX_DOMAIN_LENGTH};
pub use socks5::{Socks5Auth, Socks5Error, Socks5Handshake, Socks5Progress, Socks5Target};
pub use stream::{TransportConfig, TransportStream};
pub use tls::{
    client_hello, server_hello_for_tests, verify_client_hello_for_tests, verify_server_hello, TlsHelloError, TlsRecordReader,
    TlsRecordWriter, CLIENT_HELLO_LEN, MAX_TLS_PACKET_LENGTH,
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
