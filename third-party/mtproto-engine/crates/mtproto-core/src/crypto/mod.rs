mod aes_ctr;
mod aes_ige;
mod dh;
mod factor;
mod hash;
mod kdf;
mod prime;
mod rng;
mod rsa;

pub use aes_ctr::AesCtr;
pub use aes_ige::{aes_ige_decrypt, aes_ige_encrypt, AesIge};
pub use dh::{
    check_dh_params, check_g_a_or_b, to_fixed_be, DhError, DhPrimeCache, KNOWN_DH_PRIME, DH_PRIME_BYTES,
};
pub use factor::factorize_pq;
pub use hash::{sha1, sha1_parts, sha256, sha256_parts};
pub use kdf::{
    auth_key_aux_hash, auth_key_id, handshake_tmp_aes, message_key_v1, message_key_v2, msg_key_v1,
    msg_key_v2,
    MessageKeyMaterial, Side,
};
pub use prime::is_probable_prime;
pub use rng::{OsRandom, SecureRandom, SequenceRandom, XorShiftRandom};
pub use rsa::{RsaError, RsaPublicKey};

#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum CryptoError {
    #[error("data length {0} is not a multiple of the AES block size")]
    UnalignedLength(usize),
}
