#![allow(unsafe_code)]

use std::io::{ErrorKind, Read, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::os::fd::AsRawFd;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlackholeEnd {
    Resume,
    Reset,
    Dead,
}

#[derive(Debug, Clone, Copy)]
pub struct Blackhole {
    pub after_min: Duration,
    pub after_max: Duration,
    pub duration: Duration,
    pub end: BlackholeEnd,
}

#[derive(Debug, Clone)]
pub struct Profile {
    pub name: String,
    pub latency: Duration,
    pub jitter: Duration,
    pub bandwidth: Option<u64>,
    pub max_chunk: usize,
    pub stall_probability: f64,
    pub stall: Duration,
    pub reset_after: Option<(Duration, Duration)>,
    pub blackhole: Option<Blackhole>,
    pub refuse_probability: f64,
    pub connect_delay: Duration,
}

impl Profile {
    pub fn perfect() -> Self {
        Self {
            name: "perfect".into(),
            latency: Duration::ZERO,
            jitter: Duration::ZERO,
            bandwidth: None,
            max_chunk: 64 * 1024,
            stall_probability: 0.0,
            stall: Duration::ZERO,
            reset_after: None,
            blackhole: None,
            refuse_probability: 0.0,
            connect_delay: Duration::ZERO,
        }
    }

    pub fn broadband() -> Self {
        Self {
            name: "broadband".into(),
            latency: Duration::from_millis(15),
            jitter: Duration::from_millis(3),
            bandwidth: Some(50 * 1024 * 1024 / 8),
            ..Self::perfect()
        }
    }

    pub fn mobile_3g() -> Self {
        Self {
            name: "3g".into(),
            latency: Duration::from_millis(150),
            jitter: Duration::from_millis(60),
            bandwidth: Some(1_500_000 / 8),
            max_chunk: 1400,
            stall_probability: 0.01,
            stall: Duration::from_millis(400),
            ..Self::perfect()
        }
    }

    pub fn lossy() -> Self {
        Self {
            name: "lossy".into(),
            latency: Duration::from_millis(80),
            jitter: Duration::from_millis(40),
            bandwidth: Some(4_000_000 / 8),
            max_chunk: 1400,
            stall_probability: 0.05,
            stall: Duration::from_millis(600),
            ..Self::perfect()
        }
    }

    pub fn flaky() -> Self {
        Self {
            name: "flaky".into(),
            latency: Duration::from_millis(60),
            jitter: Duration::from_millis(30),
            bandwidth: Some(8_000_000 / 8),
            max_chunk: 4096,
            reset_after: Some((Duration::from_secs(2), Duration::from_secs(6))),
            refuse_probability: 0.2,
            connect_delay: Duration::from_millis(100),
            ..Self::perfect()
        }
    }

    pub fn blackholes() -> Self {
        Self {
            name: "blackholes".into(),
            latency: Duration::from_millis(40),
            jitter: Duration::from_millis(10),
            bandwidth: Some(10_000_000 / 8),
            blackhole: Some(Blackhole {
                after_min: Duration::from_secs(2),
                after_max: Duration::from_secs(5),
                duration: Duration::from_secs(3),
                end: BlackholeEnd::Dead,
            }),
            ..Self::perfect()
        }
    }

    pub fn by_name(name: &str) -> Option<Self> {
        match name {
            "perfect" => Some(Self::perfect()),
            "broadband" => Some(Self::broadband()),
            "3g" => Some(Self::mobile_3g()),
            "lossy" => Some(Self::lossy()),
            "flaky" => Some(Self::flaky()),
            "blackholes" => Some(Self::blackholes()),
            _ => None,
        }
    }

    pub fn all_names() -> &'static [&'static str] {
        &["perfect", "broadband", "3g", "lossy", "flaky", "blackholes"]
    }
}

#[derive(Debug, Default, Clone, Copy)]
pub struct Stats {
    pub connections: u64,
    pub refused: u64,
    pub resets: u64,
    pub blackholes: u64,
    pub bytes_up: u64,
    pub bytes_down: u64,
}

struct Bucket {
    rate: Option<f64>,
    available: f64,
    last: Instant,
}

impl Bucket {
    fn delay_for(&mut self, bytes: usize) -> Duration {
        let Some(rate) = self.rate else {
            return Duration::ZERO;
        };
        let now = Instant::now();
        let elapsed = now.duration_since(self.last).as_secs_f64();
        self.last = now;
        self.available = (self.available + elapsed * rate).min(rate * 0.05);
        self.available -= bytes as f64;
        if self.available >= 0.0 {
            Duration::ZERO
        } else {
            Duration::from_secs_f64(-self.available / rate)
        }
    }
}

struct Random(u64);

impl Random {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }

    fn unit(&mut self) -> f64 {
        (self.next() >> 11) as f64 / (1u64 << 53) as f64
    }

    fn between(&mut self, min: Duration, max: Duration) -> Duration {
        if max <= min {
            return min;
        }
        min + Duration::from_secs_f64((max - min).as_secs_f64() * self.unit())
    }
}

struct ConnectionControl {
    client: TcpStream,
    upstream: TcpStream,
    blackholed: AtomicBool,
    dead: AtomicBool,
    closed: AtomicBool,
}

impl ConnectionControl {
    fn reset(&self) {
        if self.closed.swap(true, Ordering::SeqCst) {
            return;
        }
        for stream in [&self.client, &self.upstream] {
            let linger = libc::linger { l_onoff: 1, l_linger: 0 };
            unsafe {
                libc::setsockopt(
                    stream.as_raw_fd(),
                    libc::SOL_SOCKET,
                    libc::SO_LINGER,
                    &linger as *const libc::linger as *const libc::c_void,
                    std::mem::size_of::<libc::linger>() as libc::socklen_t,
                );
            }
            let _ = stream.shutdown(Shutdown::Both);
        }
    }
}

struct Shared {
    profile: Mutex<Profile>,
    up: Mutex<Bucket>,
    down: Mutex<Bucket>,
    stop: AtomicBool,
    outage_until: Mutex<Option<Instant>>,
    live: Mutex<Vec<Arc<ConnectionControl>>>,
    connections: AtomicU64,
    refused: AtomicU64,
    resets: AtomicU64,
    blackholes: AtomicU64,
    bytes_up: AtomicU64,
    bytes_down: AtomicU64,
    seed: AtomicU64,
}

pub struct NetSim {
    pub address: SocketAddr,
    shared: Arc<Shared>,
    thread: Option<JoinHandle<()>>,
}

impl NetSim {
    pub fn start(upstream: SocketAddr, profile: Profile, seed: u64) -> std::io::Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0")?;
        listener.set_nonblocking(true)?;
        let address = listener.local_addr()?;
        let rate = profile.bandwidth.map(|value| value as f64);
        let shared = Arc::new(Shared {
            profile: Mutex::new(profile),
            up: Mutex::new(Bucket {
                rate,
                available: 0.0,
                last: Instant::now(),
            }),
            down: Mutex::new(Bucket {
                rate,
                available: 0.0,
                last: Instant::now(),
            }),
            stop: AtomicBool::new(false),
            outage_until: Mutex::new(None),
            live: Mutex::new(Vec::new()),
            connections: AtomicU64::new(0),
            refused: AtomicU64::new(0),
            resets: AtomicU64::new(0),
            blackholes: AtomicU64::new(0),
            bytes_up: AtomicU64::new(0),
            bytes_down: AtomicU64::new(0),
            seed: AtomicU64::new(seed | 1),
        });
        let thread = {
            let shared = shared.clone();
            std::thread::Builder::new().name("netsim-accept".into()).spawn(move || {
                while !shared.stop.load(Ordering::Relaxed) {
                    match listener.accept() {
                        Ok((client, _)) => {
                            let shared = shared.clone();
                            std::thread::spawn(move || handle_connection(client, upstream, shared));
                        }
                        Err(error) if error.kind() == ErrorKind::WouldBlock => std::thread::sleep(Duration::from_millis(2)),
                        Err(_) => break,
                    }
                }
            })?
        };
        Ok(Self {
            address,
            shared,
            thread: Some(thread),
        })
    }

    pub fn set_profile(&self, profile: Profile) {
        let rate = profile.bandwidth.map(|value| value as f64);
        self.shared.up.lock().unwrap().rate = rate;
        self.shared.down.lock().unwrap().rate = rate;
        *self.shared.profile.lock().unwrap() = profile;
    }

    pub fn outage(&self, duration: Duration) {
        *self.shared.outage_until.lock().unwrap() = Some(Instant::now() + duration);
        for control in self.shared.live.lock().unwrap().iter() {
            control.dead.store(true, Ordering::SeqCst);
            control.blackholed.store(true, Ordering::SeqCst);
        }
    }

    pub fn reset_all(&self) {
        let live: Vec<Arc<ConnectionControl>> = self.shared.live.lock().unwrap().drain(..).collect();
        for control in live {
            self.shared.resets.fetch_add(1, Ordering::Relaxed);
            control.reset();
        }
    }

    pub fn in_outage(&self) -> bool {
        self.shared.outage_until.lock().unwrap().is_some_and(|until| Instant::now() < until)
    }

    pub fn stats(&self) -> Stats {
        Stats {
            connections: self.shared.connections.load(Ordering::Relaxed),
            refused: self.shared.refused.load(Ordering::Relaxed),
            resets: self.shared.resets.load(Ordering::Relaxed),
            blackholes: self.shared.blackholes.load(Ordering::Relaxed),
            bytes_up: self.shared.bytes_up.load(Ordering::Relaxed),
            bytes_down: self.shared.bytes_down.load(Ordering::Relaxed),
        }
    }
}

impl Drop for NetSim {
    fn drop(&mut self) {
        self.shared.stop.store(true, Ordering::Relaxed);
        self.reset_all();
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

fn handle_connection(client: TcpStream, upstream: SocketAddr, shared: Arc<Shared>) {
    let _ = client.set_nonblocking(false);
    let profile = shared.profile.lock().unwrap().clone();
    let mut random = Random(shared.seed.fetch_add(0x9e37_79b9_7f4a_7c15, Ordering::Relaxed) | 1);
    let outage = shared.outage_until.lock().unwrap().is_some_and(|until| Instant::now() < until);
    if outage || random.unit() < profile.refuse_probability {
        shared.refused.fetch_add(1, Ordering::Relaxed);
        let linger = libc::linger { l_onoff: 1, l_linger: 0 };
        unsafe {
            libc::setsockopt(
                client.as_raw_fd(),
                libc::SOL_SOCKET,
                libc::SO_LINGER,
                &linger as *const libc::linger as *const libc::c_void,
                std::mem::size_of::<libc::linger>() as libc::socklen_t,
            );
        }
        return;
    }
    if !profile.connect_delay.is_zero() {
        std::thread::sleep(profile.connect_delay);
    }
    let Ok(upstream) = TcpStream::connect_timeout(&upstream, Duration::from_secs(10)) else {
        return;
    };
    let _ = client.set_nodelay(true);
    let _ = upstream.set_nodelay(true);
    shared.connections.fetch_add(1, Ordering::Relaxed);
    let (Ok(client_clone), Ok(upstream_clone)) = (client.try_clone(), upstream.try_clone()) else {
        return;
    };
    let control = Arc::new(ConnectionControl {
        client: client_clone,
        upstream: upstream_clone,
        blackholed: AtomicBool::new(false),
        dead: AtomicBool::new(false),
        closed: AtomicBool::new(false),
    });
    shared.live.lock().unwrap().push(control.clone());

    if let Some((min, max)) = profile.reset_after {
        let delay = random.between(min, max);
        let control = control.clone();
        let shared = shared.clone();
        std::thread::spawn(move || {
            std::thread::sleep(delay);
            if !control.closed.load(Ordering::SeqCst) {
                shared.resets.fetch_add(1, Ordering::Relaxed);
                control.reset();
            }
        });
    }
    if let Some(blackhole) = profile.blackhole {
        let delay = random.between(blackhole.after_min, blackhole.after_max);
        let control = control.clone();
        let shared = shared.clone();
        std::thread::spawn(move || {
            std::thread::sleep(delay);
            if control.closed.load(Ordering::SeqCst) {
                return;
            }
            shared.blackholes.fetch_add(1, Ordering::Relaxed);
            control.blackholed.store(true, Ordering::SeqCst);
            if blackhole.end == BlackholeEnd::Dead {
                control.dead.store(true, Ordering::SeqCst);
            }
            std::thread::sleep(blackhole.duration);
            match blackhole.end {
                BlackholeEnd::Resume => control.blackholed.store(false, Ordering::SeqCst),
                BlackholeEnd::Reset => {
                    shared.resets.fetch_add(1, Ordering::Relaxed);
                    control.reset();
                }
                BlackholeEnd::Dead => {}
            }
        });
    }

    let up_seed = random.next();
    let down_seed = random.next();
    let (Ok(client_read), Ok(upstream_read)) = (client.try_clone(), upstream.try_clone()) else {
        return;
    };
    let up = spawn_direction(client_read, upstream, shared.clone(), control.clone(), true, up_seed);
    let down = spawn_direction(upstream_read, client, shared.clone(), control.clone(), false, down_seed);
    let _ = up.join();
    let _ = down.join();
    control.closed.store(true, Ordering::SeqCst);
    shared.live.lock().unwrap().retain(|other| !Arc::ptr_eq(other, &control));
}

fn spawn_direction(
    mut source: TcpStream,
    destination: TcpStream,
    shared: Arc<Shared>,
    control: Arc<ConnectionControl>,
    upstream: bool,
    seed: u64,
) -> JoinHandle<()> {
    let (sender, receiver): (Sender<Option<(Instant, Vec<u8>)>>, Receiver<Option<(Instant, Vec<u8>)>>) = channel();
    let writer = {
        let shared = shared.clone();
        let control = control.clone();
        std::thread::spawn(move || deliver(receiver, destination, shared, control, upstream))
    };
    std::thread::spawn(move || {
        let mut random = Random(seed | 1);
        let mut buffer = vec![0u8; 64 * 1024];
        let mut last_delivery = Instant::now();
        loop {
            match source.read(&mut buffer) {
                Ok(0) | Err(_) => {
                    let _ = sender.send(None);
                    break;
                }
                Ok(read) => {
                    let profile = shared.profile.lock().unwrap().clone();
                    for chunk in buffer[..read].chunks(profile.max_chunk.max(1)) {
                        let mut delay = profile.latency + random.between(Duration::ZERO, profile.jitter);
                        if profile.stall_probability > 0.0 && random.unit() < profile.stall_probability {
                            delay += profile.stall;
                        }
                        let at = (Instant::now() + delay).max(last_delivery);
                        last_delivery = at;
                        if sender.send(Some((at, chunk.to_vec()))).is_err() {
                            return;
                        }
                    }
                }
            }
        }
        let _ = writer.join();
    })
}

fn deliver(
    receiver: Receiver<Option<(Instant, Vec<u8>)>>,
    mut destination: TcpStream,
    shared: Arc<Shared>,
    control: Arc<ConnectionControl>,
    upstream: bool,
) {
    let mut held: Vec<Vec<u8>> = Vec::new();
    loop {
        let item = match receiver.recv_timeout(Duration::from_millis(50)) {
            Ok(item) => Some(item),
            Err(RecvTimeoutError::Timeout) => None,
            Err(RecvTimeoutError::Disconnected) => return,
        };
        if control.closed.load(Ordering::SeqCst) {
            return;
        }
        if control.blackholed.load(Ordering::SeqCst) {
            if let Some(Some((_, data))) = item {
                if !control.dead.load(Ordering::SeqCst) {
                    held.push(data);
                }
            }
            continue;
        }
        for data in held.drain(..) {
            if destination.write_all(&data).is_err() {
                return;
            }
        }
        let Some(item) = item else {
            continue;
        };
        let Some((at, data)) = item else {
            let _ = destination.shutdown(Shutdown::Write);
            return;
        };
        let now = Instant::now();
        if at > now {
            std::thread::sleep(at - now);
        }
        let bucket = if upstream { &shared.up } else { &shared.down };
        let wait = bucket.lock().unwrap().delay_for(data.len());
        if !wait.is_zero() {
            std::thread::sleep(wait);
        }
        if control.blackholed.load(Ordering::SeqCst) {
            if !control.dead.load(Ordering::SeqCst) {
                held.push(data);
            }
            continue;
        }
        if destination.write_all(&data).is_err() {
            return;
        }
        let counter = if upstream { &shared.bytes_up } else { &shared.bytes_down };
        counter.fetch_add(data.len() as u64, Ordering::Relaxed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn echo_server() -> SocketAddr {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        std::thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { break };
                std::thread::spawn(move || {
                    let mut buffer = [0u8; 4096];
                    loop {
                        match stream.read(&mut buffer) {
                            Ok(0) | Err(_) => break,
                            Ok(read) => {
                                if stream.write_all(&buffer[..read]).is_err() {
                                    break;
                                }
                            }
                        }
                    }
                });
            }
        });
        address
    }

    #[test]
    fn relays_with_latency() {
        let upstream = echo_server();
        let mut profile = Profile::perfect();
        profile.latency = Duration::from_millis(50);
        let sim = NetSim::start(upstream, profile, 1).unwrap();
        let mut stream = TcpStream::connect(sim.address).unwrap();
        let started = Instant::now();
        stream.write_all(b"hello").unwrap();
        let mut reply = [0u8; 5];
        stream.read_exact(&mut reply).unwrap();
        assert_eq!(&reply, b"hello");
        assert!(started.elapsed() >= Duration::from_millis(100));
    }

    #[test]
    fn bandwidth_limit_is_enforced() {
        let upstream = echo_server();
        let mut profile = Profile::perfect();
        profile.bandwidth = Some(200_000);
        let sim = NetSim::start(upstream, profile, 2).unwrap();
        let mut stream = TcpStream::connect(sim.address).unwrap();
        let data = vec![7u8; 100_000];
        let started = Instant::now();
        let mut writer = stream.try_clone().unwrap();
        let sender = std::thread::spawn(move || writer.write_all(&data).unwrap());
        let mut received = vec![0u8; 100_000];
        stream.read_exact(&mut received).unwrap();
        sender.join().unwrap();
        assert!(started.elapsed() >= Duration::from_millis(400), "{:?}", started.elapsed());
    }

    #[test]
    fn reset_all_breaks_connections_and_outage_refuses() {
        let upstream = echo_server();
        let sim = NetSim::start(upstream, Profile::perfect(), 3).unwrap();
        let mut stream = TcpStream::connect(sim.address).unwrap();
        stream.write_all(b"x").unwrap();
        let mut one = [0u8; 1];
        stream.read_exact(&mut one).unwrap();
        sim.reset_all();
        std::thread::sleep(Duration::from_millis(50));
        let mut buffer = [0u8; 1];
        assert!(matches!(stream.read(&mut buffer), Ok(0) | Err(_)));
        sim.outage(Duration::from_millis(300));
        let mut refused = TcpStream::connect(sim.address).unwrap();
        refused.set_read_timeout(Some(Duration::from_millis(500))).unwrap();
        let _ = refused.write_all(b"y");
        assert!(matches!(refused.read(&mut buffer), Ok(0) | Err(_)));
        assert!(sim.stats().refused >= 1);
        std::thread::sleep(Duration::from_millis(350));
        let mut fine = TcpStream::connect(sim.address).unwrap();
        fine.write_all(b"z").unwrap();
        fine.read_exact(&mut buffer).unwrap();
        assert_eq!(&buffer, b"z");
    }

    #[test]
    fn dead_blackhole_stops_traffic_without_closing() {
        let upstream = echo_server();
        let mut profile = Profile::perfect();
        profile.blackhole = Some(Blackhole {
            after_min: Duration::from_millis(100),
            after_max: Duration::from_millis(100),
            duration: Duration::from_secs(10),
            end: BlackholeEnd::Dead,
        });
        let sim = NetSim::start(upstream, profile, 4).unwrap();
        let mut stream = TcpStream::connect(sim.address).unwrap();
        std::thread::sleep(Duration::from_millis(200));
        stream.set_read_timeout(Some(Duration::from_millis(300))).unwrap();
        stream.write_all(b"lost").unwrap();
        let mut buffer = [0u8; 4];
        let result = stream.read(&mut buffer);
        assert!(matches!(result, Err(ref e) if e.kind() == ErrorKind::WouldBlock || e.kind() == ErrorKind::TimedOut), "{result:?}");
    }
}
