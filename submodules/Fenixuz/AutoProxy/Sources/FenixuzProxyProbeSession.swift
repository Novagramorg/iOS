import Foundation
import TelegramCore

// Probes a candidate list of SOCKS5 proxies in concurrent batches and calls `onResult` with the
// FIRST one that passes an end-to-end health check (FenixuzSocks5Probe), or nil when the whole
// list is exhausted. The first healthy proxy wins immediately — the rest of its batch is
// cancelled. The session retains itself until it completes, so callers don't have to hold it.
final class FenixuzProxyProbeSession {
    private let candidates: [ProxyServerSettings]
    private let batchSize: Int
    private let probeTimeout: TimeInterval
    private let queue: DispatchQueue

    private var index = 0
    private var pending = 0
    private var finished = false
    private var activeProbes: [FenixuzSocks5Probe] = []
    private var onResult: ((ProxyServerSettings?) -> Void)?
    private var selfRef: FenixuzProxyProbeSession?

    init(candidates: [ProxyServerSettings], batchSize: Int, probeTimeout: TimeInterval, queue: DispatchQueue) {
        self.candidates = candidates
        self.batchSize = max(1, batchSize)
        self.probeTimeout = probeTimeout
        self.queue = queue
    }

    // `onResult` is delivered on `queue`.
    func start(onResult: @escaping (ProxyServerSettings?) -> Void) {
        self.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.onResult = onResult
            self.selfRef = self
            self.runBatch()
        }
    }

    // Runs on queue.
    private func runBatch() {
        if self.finished {
            return
        }
        if self.index >= self.candidates.count {
            self.complete(nil)
            return
        }
        let end = min(self.index + self.batchSize, self.candidates.count)
        let batch = Array(self.candidates[self.index ..< end])
        self.index = end

        var startedProbes: [FenixuzSocks5Probe] = []
        for server in batch {
            if let probe = FenixuzSocks5Probe(server: server, timeout: self.probeTimeout) {
                startedProbes.append(probe)
            }
        }
        self.activeProbes = startedProbes
        self.pending = startedProbes.count

        if self.pending == 0 {
            // Nothing probeable in this batch (all malformed) — move to the next.
            self.runBatch()
            return
        }

        for probe in startedProbes {
            let server = probe.server
            probe.start { [weak self] success in
                self?.queue.async {
                    self?.handleProbeResult(server: server, success: success)
                }
            }
        }
    }

    // Runs on queue.
    private func handleProbeResult(server: ProxyServerSettings, success: Bool) {
        if self.finished {
            return
        }
        if success {
            self.complete(server)
            return
        }
        self.pending -= 1
        if self.pending <= 0 {
            self.runBatch()
        }
    }

    // Runs on queue.
    private func complete(_ result: ProxyServerSettings?) {
        if self.finished {
            return
        }
        self.finished = true
        // Dropping the probes cancels any still-running connections via their deinit.
        self.activeProbes.removeAll()
        let onResult = self.onResult
        self.onResult = nil
        onResult?(result)
        self.selfRef = nil
    }
}
