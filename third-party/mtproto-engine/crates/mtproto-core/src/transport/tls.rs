use hmac::{Hmac, Mac};
use num_bigint::BigUint;
use num_traits::{One, Zero};
use sha2::Sha256;

use super::buffer::InputBuffer;
use super::proxy_secret::MAX_DOMAIN_LENGTH;
use crate::crypto::SecureRandom;

pub const MAX_TLS_PACKET_LENGTH: usize = 2878;
pub const CLIENT_HELLO_LEN: usize = 517;
const GREASE_SIZE: usize = 7;
const CHANGE_CIPHER_SPEC: &[u8] = b"\x14\x03\x03\x00\x01\x01";
const APPLICATION_DATA: &[u8] = b"\x17\x03\x03";

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum TlsHelloError {
    #[error("first part of response to hello is invalid")]
    InvalidPrefix,
    #[error("response hash mismatch")]
    HashMismatch,
    #[error("hello template overflow")]
    Template,
}

enum Op {
    Str(&'static [u8]),
    Random(usize),
    Zero(usize),
    Domain,
    Grease(usize),
    Key,
    BeginScope,
    EndScope,
}

const DARWIN_HELLO: &[Op] = &[
    Op::Str(b"\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03"),
    Op::Zero(32),
    Op::Str(b"\x20"),
    Op::Random(32),
    Op::Str(b"\x00\x2a"),
    Op::Grease(0),
    Op::Str(b"\x13\x01\x13\x02\x13\x03\xc0\x2c\xc0\x2b\xcc\xa9\xc0\x30\xc0\x2f\xcc\xa8\xc0\x0a\xc0\x09\xc0\x14\xc0\x13\x00\x9d\x00\x9c\x00\x35\x00\x2f\xc0\x08\xc0\x12\x00\x0a\x01\x00\x01\x89"),
    Op::Grease(2),
    Op::Str(b"\x00\x00\x00\x00"),
    Op::BeginScope,
    Op::BeginScope,
    Op::Str(b"\x00"),
    Op::BeginScope,
    Op::Domain,
    Op::EndScope,
    Op::EndScope,
    Op::EndScope,
    Op::Str(b"\x00\x17\x00\x00\xff\x01\x00\x01\x00\x00\x0a\x00\x0c\x00\x0a"),
    Op::Grease(4),
    Op::Str(b"\x00\x1d\x00\x17\x00\x18\x00\x19\x00\x0b\x00\x02\x01\x00\x00\x10\x00\x0e\x00\x0c\x02\x68\x32\x08\x68\x74\x74\x70\x2f\x31\x2e\x31\x00\x05\x00\x05\x01\x00\x00\x00\x00\x00\x0d\x00\x18\x00\x16\x04\x03\x08\x04\x04\x01\x05\x03\x02\x03\x08\x05\x08\x05\x05\x01\x08\x06\x06\x01\x02\x01\x00\x12\x00\x00\x00\x33\x00\x2b\x00\x29"),
    Op::Grease(4),
    Op::Str(b"\x00\x01\x00\x00\x1d\x00\x20"),
    Op::Key,
    Op::Str(b"\x00\x2d\x00\x02\x01\x01\x00\x2b\x00\x0b\x0a"),
    Op::Grease(6),
    Op::Str(b"\x03\x04\x03\x03\x03\x02\x03\x01\x00\x1b\x00\x03\x02\x00\x01"),
    Op::Grease(3),
    Op::Str(b"\x00\x01\x00\x00\x15"),
];

fn grease(rng: &mut impl SecureRandom) -> [u8; GREASE_SIZE] {
    let mut values = [0u8; GREASE_SIZE];
    rng.fill(&mut values);
    for value in values.iter_mut() {
        *value = (*value & 0xf0) + 0x0a;
    }
    for i in (1..GREASE_SIZE).step_by(2) {
        if values[i] == values[i - 1] {
            values[i] ^= 0x10;
        }
    }
    values
}

fn curve_modulus() -> BigUint {
    (BigUint::one() << 255u32) - BigUint::from(19u32)
}

fn y2(x: &BigUint, p: &BigUint) -> BigUint {
    let coef = BigUint::from(486662u32);
    let mut y = (x + coef) % p;
    y = (y * x) % p;
    y = (y + BigUint::one()) % p;
    (y * x) % p
}

fn double_x(x: &BigUint, p: &BigUint) -> BigUint {
    let denominator = (y2(x, p) * BigUint::from(4u32)) % p;
    let x_squared = (x * x) % p;
    let numerator = (x_squared + p - BigUint::one()) % p;
    let numerator = (&numerator * &numerator) % p;
    let inverse = denominator.modpow(&(p - BigUint::from(2u32)), p);
    (numerator * inverse) % p
}

fn is_quadratic_residue(value: &BigUint, p: &BigUint) -> bool {
    let exponent = (p - BigUint::one()) >> 1;
    value.modpow(&exponent, p).is_one()
}

fn fake_x25519_key(rng: &mut impl SecureRandom) -> [u8; 32] {
    let p = curve_modulus();
    loop {
        let mut key = [0u8; 32];
        rng.fill(&mut key);
        key[31] &= 127;
        let mut x = BigUint::from_bytes_be(&key);
        let y = y2(&x, &p);
        if y.is_zero() || !is_quadratic_residue(&y, &p) {
            continue;
        }
        for _ in 0..3 {
            x = double_x(&x, &p);
        }
        let le = x.to_bytes_le();
        let mut out = [0u8; 32];
        out[..le.len()].copy_from_slice(&le);
        return out;
    }
}

pub fn client_hello(domain: &[u8], secret: &[u8; 16], unix_time: i32, rng: &mut impl SecureRandom) -> Vec<u8> {
    let domain = &domain[..domain.len().min(MAX_DOMAIN_LENGTH)];
    let greases = grease(rng);
    let mut data = Vec::with_capacity(CLIENT_HELLO_LEN);
    let mut scopes = Vec::new();
    for op in DARWIN_HELLO {
        match op {
            Op::Str(bytes) => data.extend_from_slice(bytes),
            Op::Random(length) => {
                let start = data.len();
                data.resize(start + length, 0);
                rng.fill(&mut data[start..]);
            }
            Op::Zero(length) => data.resize(data.len() + length, 0),
            Op::Domain => data.extend_from_slice(domain),
            Op::Grease(index) => data.extend_from_slice(&[greases[*index], greases[*index]]),
            Op::Key => data.extend_from_slice(&fake_x25519_key(rng)),
            Op::BeginScope => {
                scopes.push(data.len());
                data.extend_from_slice(&[0, 0]);
            }
            Op::EndScope => close_scope(&mut data, &mut scopes),
        }
    }
    assert!(data.len() <= 514, "hello template too long");
    let zero_pad = 515 - data.len();
    scopes.push(data.len());
    data.extend_from_slice(&[0, 0]);
    data.resize(data.len() + zero_pad, 0);
    close_scope(&mut data, &mut scopes);
    debug_assert!(scopes.is_empty());
    debug_assert_eq!(data.len(), CLIENT_HELLO_LEN);

    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(secret).expect("any key length");
    mac.update(&data);
    let mut hash: [u8; 32] = mac.finalize().into_bytes().into();
    let tail = i32::from_le_bytes(hash[28..32].try_into().expect("4")) ^ unix_time;
    hash[28..32].copy_from_slice(&tail.to_le_bytes());
    data[11..43].copy_from_slice(&hash);
    data
}

fn close_scope(data: &mut [u8], scopes: &mut Vec<usize>) {
    let begin = scopes.pop().expect("balanced scopes");
    let size = data.len() - begin - 2;
    assert!(size < (1 << 14), "scope too large");
    data[begin] = (size >> 8) as u8;
    data[begin + 1] = size as u8;
}

pub fn verify_server_hello(
    buffer: &mut InputBuffer,
    client_random: &[u8; 32],
    secret: &[u8; 16],
) -> Result<bool, TlsHelloError> {
    let data = buffer.as_slice();
    let mut position = 0usize;
    for prefix in [&b"\x16\x03\x03"[..], &b"\x14\x03\x03\x00\x01\x01\x17\x03\x03"[..]] {
        if data.len() < position + prefix.len() + 2 {
            return Ok(false);
        }
        if &data[position..position + prefix.len()] != prefix {
            return Err(TlsHelloError::InvalidPrefix);
        }
        position += prefix.len();
        let skip = ((data[position] as usize) << 8) | data[position + 1] as usize;
        position += 2;
        if data.len() < position + skip {
            return Ok(false);
        }
        position += skip;
    }
    if position < 43 {
        return Err(TlsHelloError::InvalidPrefix);
    }
    let mut response = data[..position].to_vec();
    let received: [u8; 32] = response[11..43].try_into().expect("32");
    response[11..43].fill(0);
    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(secret).expect("any key length");
    mac.update(client_random);
    mac.update(&response);
    mac.verify_slice(&received).map_err(|_| TlsHelloError::HashMismatch)?;
    buffer.consume(position);
    Ok(true)
}

#[derive(Debug, Default)]
pub struct TlsRecordWriter {
    sent_first: bool,
}

impl TlsRecordWriter {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn write(&mut self, payload: &[u8], out: &mut Vec<u8>) {
        if !self.sent_first {
            self.sent_first = true;
            out.extend_from_slice(CHANGE_CIPHER_SPEC);
        }
        for chunk in payload.chunks(MAX_TLS_PACKET_LENGTH) {
            out.extend_from_slice(APPLICATION_DATA);
            out.extend_from_slice(&(chunk.len() as u16).to_be_bytes());
            out.extend_from_slice(chunk);
        }
    }
}

#[derive(Debug, Default)]
pub struct TlsRecordReader;

impl TlsRecordReader {
    pub fn new() -> Self {
        Self
    }

    pub fn read(&mut self, input: &mut InputBuffer, output: &mut Vec<u8>) -> Result<bool, super::TransportError> {
        let data = input.as_slice();
        if data.len() < 5 {
            return Ok(false);
        }
        if &data[..3] != APPLICATION_DATA {
            return Err(super::TransportError::InvalidTlsRecord);
        }
        let length = ((data[3] as usize) << 8) | data[4] as usize;
        if data.len() < 5 + length {
            return Ok(false);
        }
        output.extend_from_slice(&data[5..5 + length]);
        input.consume(5 + length);
        Ok(true)
    }
}

pub fn server_hello_for_tests(client_hello: &[u8], secret: &[u8; 16], rng: &mut impl SecureRandom) -> Vec<u8> {
    let mut body = vec![0u8; 80];
    rng.fill(&mut body);
    let mut response = Vec::new();
    response.extend_from_slice(b"\x16\x03\x03");
    response.extend_from_slice(&(body.len() as u16).to_be_bytes());
    response.extend_from_slice(&body);
    response[11..43].fill(0);
    response.extend_from_slice(b"\x14\x03\x03\x00\x01\x01\x17\x03\x03");
    let app = vec![0x55u8; 40];
    response.extend_from_slice(&(app.len() as u16).to_be_bytes());
    response.extend_from_slice(&app);
    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(secret).expect("any key length");
    mac.update(&client_hello[11..43]);
    mac.update(&response);
    let hash = mac.finalize().into_bytes();
    response[11..43].copy_from_slice(&hash);
    response
}

pub fn verify_client_hello_for_tests(hello: &[u8], secret: &[u8; 16]) -> Option<i32> {
    if hello.len() != CLIENT_HELLO_LEN {
        return None;
    }
    let mut zeroed = hello.to_vec();
    zeroed[11..43].fill(0);
    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(secret).expect("any key length");
    mac.update(&zeroed);
    let expected = mac.finalize().into_bytes();
    if hello[11..39] != expected[..28] {
        return None;
    }
    let received = i32::from_le_bytes(hello[39..43].try_into().expect("4"));
    let computed = i32::from_le_bytes(expected[28..32].try_into().expect("4"));
    Some(received ^ computed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::XorShiftRandom;

    #[test]
    fn hello_shape() {
        let mut rng = XorShiftRandom::new(1);
        let hello = client_hello(b"www.google.com", &[3u8; 16], 1_700_000_000, &mut rng);
        assert_eq!(hello.len(), CLIENT_HELLO_LEN);
        assert_eq!(&hello[..5], b"\x16\x03\x01\x02\x00");
        assert_eq!(&hello[5..9], b"\x01\x00\x01\xfc");
        assert_eq!(hello[43], 0x20);
        let domain_pos = hello.windows(14).position(|w| w == b"www.google.com").unwrap();
        assert_eq!(&hello[domain_pos - 2..domain_pos], &[0, 14]);
        assert_eq!(hello[domain_pos - 3], 0);
        assert_eq!(&hello[domain_pos - 5..domain_pos - 3], &[0, 17]);
        assert_eq!(&hello[domain_pos - 7..domain_pos - 5], &[0, 19]);
    }

    #[test]
    fn hello_hmac_encodes_time() {
        let mut rng = XorShiftRandom::new(2);
        let secret = [9u8; 16];
        let hello = client_hello(b"example.org", &secret, 1_234_567, &mut rng);
        assert_eq!(verify_client_hello_for_tests(&hello, &secret), Some(1_234_567));
        assert_eq!(verify_client_hello_for_tests(&hello, &[8u8; 16]), None);
    }

    #[test]
    fn long_domain_is_truncated() {
        let mut rng = XorShiftRandom::new(3);
        let domain = vec![b'a'; 400];
        let hello = client_hello(&domain, &[1u8; 16], 0, &mut rng);
        assert_eq!(hello.len(), CLIENT_HELLO_LEN);
    }

    #[test]
    fn grease_pairs_differ() {
        let mut rng = XorShiftRandom::new(4);
        for _ in 0..100 {
            let g = grease(&mut rng);
            for value in g {
                assert_eq!(value & 0x0f, 0x0a);
            }
            for i in (1..GREASE_SIZE).step_by(2) {
                assert_ne!(g[i], g[i - 1]);
            }
        }
    }

    #[test]
    fn fake_key_is_on_curve() {
        let mut rng = XorShiftRandom::new(5);
        let p = curve_modulus();
        for _ in 0..5 {
            let key = fake_x25519_key(&mut rng);
            let x = BigUint::from_bytes_le(&key);
            assert!(x < p);
            assert!(is_quadratic_residue(&y2(&x, &p), &p) || y2(&x, &p).is_zero());
        }
    }

    #[test]
    fn server_hello_roundtrip() {
        let mut rng = XorShiftRandom::new(6);
        let secret = [5u8; 16];
        let hello = client_hello(b"cdn.example", &secret, 99, &mut rng);
        let response = server_hello_for_tests(&hello, &secret, &mut rng);
        let random: [u8; 32] = hello[11..43].try_into().unwrap();
        let mut buffer = InputBuffer::new();
        for (index, byte) in response.iter().enumerate() {
            buffer.extend(&[*byte]);
            let done = verify_server_hello(&mut buffer, &random, &secret).unwrap();
            assert_eq!(done, index == response.len() - 1);
        }
        assert!(buffer.is_empty());

        let mut tampered = response.clone();
        tampered[60] ^= 1;
        let mut buffer = InputBuffer::new();
        buffer.extend(&tampered);
        assert_eq!(verify_server_hello(&mut buffer, &random, &secret), Err(TlsHelloError::HashMismatch));

        let mut buffer = InputBuffer::new();
        buffer.extend(b"\x15\x03\x03\x00\x02ab");
        assert_eq!(verify_server_hello(&mut buffer, &random, &secret), Err(TlsHelloError::InvalidPrefix));
    }

    #[test]
    fn zero_length_and_split_records_do_not_stall() {
        let mut input = InputBuffer::new();
        let mut reader = TlsRecordReader::new();
        let mut collected = Vec::new();
        input.extend(b"\x17\x03\x03\x00\x00");
        input.extend(b"\x17\x03\x03\x00\x03ab");
        assert!(reader.read(&mut input, &mut collected).unwrap());
        assert!(collected.is_empty());
        assert!(!reader.read(&mut input, &mut collected).unwrap());
        input.extend(b"c");
        assert!(reader.read(&mut input, &mut collected).unwrap());
        assert_eq!(collected, b"abc");
        assert!(input.is_empty());
    }

    #[test]
    fn record_writer_and_reader() {
        let mut writer = TlsRecordWriter::new();
        let mut out = Vec::new();
        let payload = vec![7u8; MAX_TLS_PACKET_LENGTH * 2 + 10];
        writer.write(&payload, &mut out);
        writer.write(&[1, 2, 3], &mut out);
        assert_eq!(&out[..6], CHANGE_CIPHER_SPEC);
        let mut input = InputBuffer::new();
        input.extend(&out[6..]);
        let mut reader = TlsRecordReader::new();
        let mut collected = Vec::new();
        while reader.read(&mut input, &mut collected).unwrap() {}
        assert!(input.is_empty());
        assert_eq!(collected.len(), payload.len() + 3);
        let mut bad = InputBuffer::new();
        bad.extend(b"\x16\x03\x03\x00\x01x");
        assert!(reader.read(&mut bad, &mut collected).is_err());
    }
}
