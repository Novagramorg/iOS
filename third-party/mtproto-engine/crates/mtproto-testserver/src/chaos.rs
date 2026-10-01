use mtproto_core::crypto::{SecureRandom, XorShiftRandom};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Fault {
    DropBeforeExecution,
    DropAfterExecution,
    RotateSalt,
    ExpireSalt,
    ResendRequest,
    UnknownSibling,
    FloodWait,
    InternalError,
    TransportFlood,
    SlowAnswer,
    DuplicateAnswer,
    GzipAnswer,
    MsgCopy,
    ServerPing,
    AckNoise,
    Stall,
    NewSession,
}

impl Fault {
    pub const ALL: [Fault; 17] = [
        Fault::DropBeforeExecution,
        Fault::DropAfterExecution,
        Fault::RotateSalt,
        Fault::ExpireSalt,
        Fault::ResendRequest,
        Fault::UnknownSibling,
        Fault::FloodWait,
        Fault::InternalError,
        Fault::TransportFlood,
        Fault::SlowAnswer,
        Fault::DuplicateAnswer,
        Fault::GzipAnswer,
        Fault::MsgCopy,
        Fault::ServerPing,
        Fault::AckNoise,
        Fault::Stall,
        Fault::NewSession,
    ];

    pub fn name(self) -> &'static str {
        match self {
            Fault::DropBeforeExecution => "drop-before",
            Fault::DropAfterExecution => "drop-after",
            Fault::RotateSalt => "rotate-salt",
            Fault::ExpireSalt => "expire-salt",
            Fault::ResendRequest => "resend-req",
            Fault::UnknownSibling => "unknown-sibling",
            Fault::FloodWait => "flood-wait",
            Fault::InternalError => "internal-error",
            Fault::TransportFlood => "transport-flood",
            Fault::SlowAnswer => "slow-answer",
            Fault::DuplicateAnswer => "duplicate-answer",
            Fault::GzipAnswer => "gzip-answer",
            Fault::MsgCopy => "msg-copy",
            Fault::ServerPing => "server-ping",
            Fault::AckNoise => "ack-noise",
            Fault::Stall => "stall",
            Fault::NewSession => "new-session",
        }
    }

    pub fn by_name(name: &str) -> Option<Fault> {
        Fault::ALL.into_iter().find(|fault| fault.name() == name)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ChaosConfig {
    pub seed: u64,
    pub faults: Vec<(Fault, f64)>,
}

impl ChaosConfig {
    pub fn only(seed: u64, fault: Fault, rate: f64) -> Self {
        Self { seed, faults: vec![(fault, rate)] }
    }

    pub fn mixed(seed: u64, rate_each: f64) -> Self {
        Self {
            seed,
            faults: Fault::ALL
                .into_iter()
                .filter(|fault| *fault != Fault::NewSession)
                .map(|fault| (fault, rate_each))
                .collect(),
        }
    }

    pub fn roll(&self, rng: &mut XorShiftRandom) -> Option<Fault> {
        let sample = (rng.next_u64() >> 11) as f64 / (1u64 << 53) as f64;
        let mut cumulative = 0.0;
        for (fault, rate) in &self.faults {
            cumulative += rate;
            if sample < cumulative {
                return Some(*fault);
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rates_are_respected_and_names_round_trip() {
        let config = ChaosConfig::mixed(1, 0.01);
        let mut rng = XorShiftRandom::new(9);
        let mut hits = 0;
        for _ in 0..100_000 {
            if config.roll(&mut rng).is_some() {
                hits += 1;
            }
        }
        let expected = 100_000.0 * 0.01 * (Fault::ALL.len() - 1) as f64;
        assert!((hits as f64 - expected).abs() < expected * 0.1, "{hits} vs {expected}");
        for fault in Fault::ALL {
            assert_eq!(Fault::by_name(fault.name()), Some(fault));
        }
    }
}
