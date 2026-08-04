import Foundation
import TONConnect

/// One live bridge connection and the pump task feeding it into the kit.
///
/// The bridge multiplexes: a single SSE connection carries traffic for every session whose
/// key appears in the `client_id` list. So there is one of these per *bridge URL*, not per
/// session — a wallet with twenty dApp connections on the same bridge holds one socket, not
/// twenty.
struct BridgeSubscription {
    let client: BridgeClient
    let task: Task<Void, Never>
    /// Session ids this connection covers, so a change can be detected without rebuilding.
    let sessionIDs: Set<String>

    func cancel() {
        task.cancel()
        client.close()
    }
}

/// Persists the bridge's `Last-Event-ID` so a reconnect resumes rather than replays.
///
/// Without this, every reconnect re-delivers whatever backlog the bridge still holds, and the
/// user sees confirmation sheets for requests they already answered. Scoped per bridge URL
/// because the cursor is only meaningful to the bridge that issued it.
actor BridgeCursorStore: LastEventIDStore {
    private let storage: any WalletKitStorage
    private let key: String

    init(storage: any WalletKitStorage, bridgeURL: URL) {
        self.storage = storage
        self.key = "\(StorageKey.bridgeCursorPrefix)\(bridgeURL.absoluteString)"
    }

    func load() async -> String? {
        await storage.getJSON(key)
    }

    func save(_ id: String) async {
        try? await storage.setJSON(key, id)
    }
}
