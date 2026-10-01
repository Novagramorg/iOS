#![deny(unsafe_code)]

mod clock;
mod connection;
mod resolver;
mod session_runtime;
mod types;
mod worker;

use std::io;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc::{channel, Sender};
use std::sync::{Arc, Mutex};
use std::thread::JoinHandle;

use mio::{Poll, Waker};
pub use mtproto_core;
use mtproto_core::rpc::{ApiEnvironment, RequestId, RpcRequest, SessionRole, Verification};

pub use clock::{monotonic_seconds, now, unix_seconds};
pub use types::{
    AuthKeyMaterial, ConnectionState, DcAddress, EngineCallbacks, EngineConfig, EngineEvent, KeyGeneration, LogLevel,
    ProxyConfig, SessionHandle, SessionSetup,
};
use worker::{Command, Worker, WAKER_TOKEN};

struct WorkerHandle {
    sender: Mutex<Sender<Command>>,
    waker: Arc<Waker>,
    thread: Mutex<Option<JoinHandle<()>>>,
}

struct EngineInner {
    workers: Vec<WorkerHandle>,
    next_session: AtomicU64,
    next_request: AtomicU64,
    round_robin: AtomicUsize,
}

#[derive(Clone)]
pub struct Engine {
    inner: Arc<EngineInner>,
}

const WORKER_BITS: u64 = 8;

impl Engine {
    pub fn new(config: EngineConfig, callbacks: Arc<dyn EngineCallbacks>) -> io::Result<Self> {
        let count = config.worker_threads.clamp(1, 16);
        let mut workers = Vec::with_capacity(count);
        for index in 0..count {
            let poll = Poll::new()?;
            let waker = Arc::new(Waker::new(poll.registry(), WAKER_TOKEN)?);
            let (sender, receiver) = channel();
            let worker = Worker::new(poll, receiver, sender.clone(), waker.clone(), callbacks.clone(), config.clone());
            let thread = std::thread::Builder::new()
                .name(if index == 0 { "mtproto-main".into() } else { format!("mtproto-worker-{index}") })
                .stack_size(512 * 1024)
                .spawn(move || worker.run())?;
            workers.push(WorkerHandle {
                sender: Mutex::new(sender),
                waker,
                thread: Mutex::new(Some(thread)),
            });
        }
        Ok(Self {
            inner: Arc::new(EngineInner {
                workers,
                next_session: AtomicU64::new(1),
                next_request: AtomicU64::new(1),
                round_robin: AtomicUsize::new(0),
            }),
        })
    }

    pub fn worker_count(&self) -> usize {
        self.inner.workers.len()
    }

    pub fn next_request_id(&self) -> RequestId {
        RequestId(self.inner.next_request.fetch_add(1, Ordering::Relaxed))
    }

    fn worker_for(&self, handle: SessionHandle) -> &WorkerHandle {
        let index = (handle.0 & ((1 << WORKER_BITS) - 1)) as usize;
        &self.inner.workers[index.min(self.inner.workers.len() - 1)]
    }

    fn post(&self, handle: SessionHandle, command: Command) {
        let worker = self.worker_for(handle);
        if let Ok(sender) = worker.sender.lock() {
            if sender.send(command).is_ok() {
                let _ = worker.waker.wake();
            }
        }
    }

    fn broadcast(&self, make: impl Fn() -> Command) {
        for worker in &self.inner.workers {
            if let Ok(sender) = worker.sender.lock() {
                if sender.send(make()).is_ok() {
                    let _ = worker.waker.wake();
                }
            }
        }
    }

    pub fn create_session(&self, setup: SessionSetup) -> SessionHandle {
        let count = self.inner.workers.len();
        let worker = if count == 1 || setup.role == SessionRole::Main {
            0
        } else {
            1 + self.inner.round_robin.fetch_add(1, Ordering::Relaxed) % (count - 1)
        };
        let serial = self.inner.next_session.fetch_add(1, Ordering::Relaxed);
        let handle = SessionHandle((serial << WORKER_BITS) | worker as u64);
        self.post(
            handle,
            Command::Create {
                handle,
                setup: Box::new(setup),
            },
        );
        handle
    }

    pub fn destroy_session(&self, handle: SessionHandle) {
        self.post(handle, Command::Destroy(handle));
    }

    pub fn send(&self, handle: SessionHandle, request: RpcRequest) {
        self.post(handle, Command::Send(handle, request));
    }

    pub fn cancel(&self, handle: SessionHandle, id: RequestId) {
        self.post(handle, Command::Cancel(handle, id));
    }

    pub fn set_paused(&self, handle: SessionHandle, paused: bool) {
        self.post(handle, Command::SetPaused(handle, paused));
    }

    pub fn set_online(&self, handle: SessionHandle, online: bool) {
        self.post(handle, Command::SetOnline(handle, online));
    }

    pub fn set_auth_key(&self, handle: SessionHandle, material: Option<AuthKeyMaterial>) {
        self.post(handle, Command::SetAuthKey(handle, material));
    }

    pub fn set_addresses(&self, handle: SessionHandle, addresses: Vec<DcAddress>) {
        self.post(handle, Command::SetAddresses(handle, addresses));
    }

    pub fn set_proxy(&self, handle: SessionHandle, proxy: Option<ProxyConfig>) {
        self.post(handle, Command::SetProxy(handle, proxy));
    }

    pub fn update_environment(&self, handle: SessionHandle, environment: ApiEnvironment, noop: Option<RpcRequest>) {
        self.post(handle, Command::UpdateEnvironment(handle, Box::new(environment), noop));
    }

    pub fn set_auth_token_ready(&self, handle: SessionHandle, ready: bool) {
        self.post(handle, Command::SetAuthTokenReady(handle, ready));
    }

    pub fn resolve_verification(&self, handle: SessionHandle, id: RequestId, verification: Verification) {
        self.post(handle, Command::ResolveVerification(handle, id, verification));
    }

    pub fn fail_request(&self, handle: SessionHandle, id: RequestId, code: i32, message: String) {
        self.post(handle, Command::FailRequest(handle, id, code, message));
    }

    pub fn decide_retry(&self, handle: SessionHandle, id: RequestId, retry: bool) {
        self.post(handle, Command::DecideRetry(handle, id, retry));
    }

    pub fn invalidate_initialization(&self, handle: SessionHandle) {
        self.post(handle, Command::InvalidateInitialization(handle));
    }

    pub fn set_time_difference(&self, handle: SessionHandle, difference: f64) {
        self.post(handle, Command::SetTimeDifference(handle, difference));
    }

    pub fn set_network_available(&self, available: bool) {
        self.broadcast(|| Command::SetNetworkAvailable(available));
    }

    pub fn reset_connections(&self) {
        self.broadcast(|| Command::ResetConnections);
    }

    pub fn shutdown(&self) {
        self.broadcast(|| Command::Shutdown);
        for worker in &self.inner.workers {
            if let Ok(mut thread) = worker.thread.lock() {
                if let Some(thread) = thread.take() {
                    if thread.thread().id() != std::thread::current().id() {
                        let _ = thread.join();
                    }
                }
            }
        }
    }
}

impl Drop for EngineInner {
    fn drop(&mut self) {
        for worker in &self.workers {
            if let Ok(sender) = worker.sender.lock() {
                let _ = sender.send(Command::Shutdown);
                let _ = worker.waker.wake();
            }
        }
        for worker in &self.workers {
            if let Ok(mut thread) = worker.thread.lock() {
                if let Some(thread) = thread.take() {
                    if thread.thread().id() != std::thread::current().id() {
                        let _ = thread.join();
                    }
                }
            }
        }
    }
}
