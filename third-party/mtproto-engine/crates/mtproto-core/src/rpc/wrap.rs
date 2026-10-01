use crate::tl::{ids, Writer};

pub const INIT_CONNECTION: u32 = 0xc1cd5ea9;
pub const INPUT_CLIENT_PROXY: u32 = 0x75588b3f;
pub const INVOKE_WITH_APNS_SECRET: u32 = 0x0dae54f8;
pub const INVOKE_WITH_RECAPTCHA: u32 = 0xadbb0f94;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientProxy {
    pub address: String,
    pub port: i32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ApiEnvironment {
    pub layer: i32,
    pub api_id: i32,
    pub device_model: String,
    pub system_version: String,
    pub app_version: String,
    pub system_lang_code: String,
    pub lang_pack: String,
    pub lang_code: String,
    pub proxy: Option<ClientProxy>,
    pub params: Option<Vec<u8>>,
    pub init_hash: String,
    pub disable_updates: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Verification {
    Apns { nonce: String, secret: String },
    Recaptcha { token: String },
}

pub fn wrap_request(
    payload: &[u8],
    initialize: Option<&ApiEnvironment>,
    without_updates: bool,
    verification: Option<&Verification>,
) -> Vec<u8> {
    let mut writer = Writer::with_capacity(payload.len() + 256);
    match verification {
        Some(Verification::Recaptcha { token }) => {
            writer.write_u32(INVOKE_WITH_RECAPTCHA);
            writer.write_bytes(token.as_bytes());
        }
        Some(Verification::Apns { nonce, secret }) => {
            writer.write_u32(INVOKE_WITH_APNS_SECRET);
            writer.write_bytes(nonce.as_bytes());
            writer.write_bytes(secret.as_bytes());
        }
        None => {}
    }
    if without_updates {
        writer.write_u32(ids::INVOKE_WITHOUT_UPDATES);
    }
    if let Some(environment) = initialize {
        writer.write_u32(ids::INVOKE_WITH_LAYER);
        writer.write_i32(environment.layer);
        writer.write_u32(INIT_CONNECTION);
        let mut flags = 0i32;
        if environment.proxy.is_some() {
            flags |= 1;
        }
        if environment.params.is_some() {
            flags |= 2;
        }
        writer.write_i32(flags);
        writer.write_i32(environment.api_id);
        writer.write_bytes(environment.device_model.as_bytes());
        writer.write_bytes(environment.system_version.as_bytes());
        writer.write_bytes(environment.app_version.as_bytes());
        writer.write_bytes(environment.system_lang_code.as_bytes());
        writer.write_bytes(environment.lang_pack.as_bytes());
        writer.write_bytes(environment.lang_code.as_bytes());
        if let Some(proxy) = &environment.proxy {
            writer.write_u32(INPUT_CLIENT_PROXY);
            writer.write_bytes(proxy.address.as_bytes());
            writer.write_i32(proxy.port);
        }
        if let Some(params) = &environment.params {
            writer.write_raw(params);
        }
    }
    writer.write_raw(payload);
    writer.into_inner()
}

pub fn flood_wait_seconds(message: &str) -> Option<i64> {
    for marker in ["FLOOD_PREMIUM_WAIT_", "FLOOD_WAIT_"] {
        if let Some(position) = message.find(marker) {
            let digits: String = message[position + marker.len()..]
                .chars()
                .take_while(|c| c.is_ascii_digit())
                .collect();
            return digits.parse::<i64>().ok();
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::tl::Reader;

    fn environment() -> ApiEnvironment {
        ApiEnvironment {
            layer: 230,
            api_id: 9,
            device_model: "MacBookPro18,3".into(),
            system_version: "macOS 26.4".into(),
            app_version: "12.6".into(),
            system_lang_code: "en".into(),
            lang_pack: "macos".into(),
            lang_code: "en".into(),
            proxy: None,
            params: None,
            init_hash: "hash".into(),
            disable_updates: false,
        }
    }

    #[test]
    fn plain_payload_is_unchanged() {
        assert_eq!(wrap_request(&[1, 2, 3, 4], None, false, None), vec![1, 2, 3, 4]);
    }

    #[test]
    fn init_connection_layout() {
        let mut env = environment();
        env.proxy = Some(ClientProxy {
            address: "1.2.3.4".into(),
            port: 443,
        });
        env.params = Some(vec![0xaa, 0xbb, 0xcc, 0xdd]);
        let wrapped = wrap_request(&[9, 9, 9, 9], Some(&env), true, None);
        let mut reader = Reader::new(&wrapped);
        assert_eq!(reader.read_u32().unwrap(), ids::INVOKE_WITHOUT_UPDATES);
        assert_eq!(reader.read_u32().unwrap(), ids::INVOKE_WITH_LAYER);
        assert_eq!(reader.read_i32().unwrap(), 230);
        assert_eq!(reader.read_u32().unwrap(), INIT_CONNECTION);
        assert_eq!(reader.read_i32().unwrap(), 3);
        assert_eq!(reader.read_i32().unwrap(), 9);
        assert_eq!(reader.read_bytes().unwrap(), b"MacBookPro18,3");
        assert_eq!(reader.read_bytes().unwrap(), b"macOS 26.4");
        assert_eq!(reader.read_bytes().unwrap(), b"12.6");
        assert_eq!(reader.read_bytes().unwrap(), b"en");
        assert_eq!(reader.read_bytes().unwrap(), b"macos");
        assert_eq!(reader.read_bytes().unwrap(), b"en");
        assert_eq!(reader.read_u32().unwrap(), INPUT_CLIENT_PROXY);
        assert_eq!(reader.read_bytes().unwrap(), b"1.2.3.4");
        assert_eq!(reader.read_i32().unwrap(), 443);
        assert_eq!(reader.read_array::<4>().unwrap(), [0xaa, 0xbb, 0xcc, 0xdd]);
        assert_eq!(reader.read_array::<4>().unwrap(), [9, 9, 9, 9]);
        assert!(reader.finish().is_ok());
    }

    #[test]
    fn verification_wrappers_are_outermost() {
        let apns = wrap_request(
            &[1, 1, 1, 1],
            None,
            true,
            Some(&Verification::Apns {
                nonce: "n".into(),
                secret: "s".into(),
            }),
        );
        let mut reader = Reader::new(&apns);
        assert_eq!(reader.read_u32().unwrap(), INVOKE_WITH_APNS_SECRET);
        assert_eq!(reader.read_bytes().unwrap(), b"n");
        assert_eq!(reader.read_bytes().unwrap(), b"s");
        assert_eq!(reader.read_u32().unwrap(), ids::INVOKE_WITHOUT_UPDATES);
        let recaptcha = wrap_request(&[1, 1, 1, 1], None, false, Some(&Verification::Recaptcha { token: "t".into() }));
        assert_eq!(&recaptcha[..4], &INVOKE_WITH_RECAPTCHA.to_le_bytes());
    }

    #[test]
    fn flood_wait_parsing() {
        assert_eq!(flood_wait_seconds("FLOOD_WAIT_17"), Some(17));
        assert_eq!(flood_wait_seconds("FLOOD_PREMIUM_WAIT_3"), Some(3));
        assert_eq!(flood_wait_seconds("FLOOD_WAIT_0"), Some(0));
        assert_eq!(flood_wait_seconds("SLOWMODE_WAIT_10"), None);
        assert_eq!(flood_wait_seconds("FLOOD_WAIT_"), None);
        assert_eq!(flood_wait_seconds("2FA_CONFIRM_WAIT_100"), None);
    }
}
