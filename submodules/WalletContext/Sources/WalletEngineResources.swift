import Foundation
import WalletEngineFFI

enum WalletEngineResourceStatus: Equatable {
    case idle
    case loading
    case ready
    case failed(WalletContext.SynchronizationError)
    case cancelled
    case skipped
}

func walletEngineResourceStatus(_ resource: ResourceState, outcome: WalletOperationOutcome? = nil) -> WalletEngineResourceStatus {
    switch outcome {
    case .cancelled, .superseded:
        return .cancelled
    case .skipped:
        return .skipped
    case .completed, .partiallyCompleted, .failed, .none:
        break
    }
    if resource.error?.code == .hostCancelled {
        return .cancelled
    }
    if outcome == .failed || resource.phase == .failed {
        return .failed(synchronizationError(resource.error))
    }
    switch resource.phase {
    case .ready:
        return .ready
    case .idle:
        return outcome == nil ? .idle : .failed(.invalidData)
    case .loading:
        return outcome == nil ? .loading : .failed(.invalidData)
    case .failed:
        return .failed(synchronizationError(resource.error))
    }
}

func walletEngineCollectibles(
    _ update: WalletUpdate,
    pagination: Bool,
    loadMetadata: ([NftItem]) async throws -> [WalletContext.Collectible]
) async throws -> [WalletContext.Collectible]? {
    try Task.checkCancellation()
    let resource = pagination ? update.snapshot.nfts.paginationResource : update.snapshot.nfts.resource
    switch walletEngineResourceStatus(resource, outcome: update.outcome) {
    case .ready:
        let items = try await loadMetadata(update.snapshot.nfts.items)
        try Task.checkCancellation()
        return items
    case let .failed(error):
        throw error
    case .cancelled:
        throw CancellationError()
    case .skipped:
        return nil
    case .idle, .loading:
        throw WalletContext.SynchronizationError.invalidData
    }
}

func walletEngineCollectiblesState(
    previous: WalletContext.CollectiblesState,
    items: [WalletContext.Collectible]?,
    hasMore: Bool,
    pagination: Bool = true
) -> WalletContext.CollectiblesState {
    WalletContext.CollectiblesState(
        items: items ?? previous.items,
        offset: items?.count ?? previous.offset,
        canLoadMore: hasMore,
        isLoadingMore: pagination ? false : previous.isLoadingMore,
        error: items == nil ? previous.error : nil
    )
}

func walletEngineCollectiblesState(
    previous: WalletContext.CollectiblesState,
    failure: Error,
    pagination: Bool = true
) -> WalletContext.CollectiblesState {
    WalletContext.CollectiblesState(
        items: previous.items,
        offset: previous.offset,
        canLoadMore: previous.canLoadMore,
        isLoadingMore: pagination ? false : previous.isLoadingMore,
        error: failure is CancellationError ? previous.error : synchronizationError(failure)
    )
}

struct WalletEngineCollectiblesRevision {
    private(set) var latest: UInt64?

    func isCurrent(_ revision: UInt64) -> Bool {
        self.latest.map { revision >= $0 } ?? true
    }

    mutating func accept(_ revision: UInt64) -> Bool {
        guard self.isCurrent(revision) else { return false }
        self.latest = revision
        return true
    }
}

struct WalletEngineBalanceTracker {
    private struct Observation: Equatable {
        let account: AccountSnapshot?
        let resource: ResourceState
    }

    private struct Refresh {
        let id: UUID
        var publishedSuccess = false
    }

    private var observation: Observation?
    private var latestRevision: UInt64?
    private var stableBalance: WalletContext.Resource<Int64>?
    private var refresh: Refresh?

    mutating func beginRefresh(id: UUID) {
        self.refresh = Refresh(id: id)
    }

    mutating func observe(
        _ snapshot: WalletSnapshot,
        current: WalletContext.Resource<Int64>,
        lastSuccessfulAt: Int32?,
        now: Int32
    ) -> WalletContext.Resource<Int64> {
        if let latestRevision = self.latestRevision, snapshot.revision <= latestRevision {
            return current
        }
        self.latestRevision = snapshot.revision
        let observation = Observation(account: snapshot.account, resource: snapshot.accountResource)
        guard observation != self.observation else { return current }
        let isInitialObservation = self.observation == nil
        self.observation = observation
        let timestamp = isInitialObservation && self.refresh == nil
            && snapshot.account.flatMap({ walletEngineBalance($0.balanceNanograms) }) == current.currentValue
            ? (lastSuccessfulAt ?? now) : now
        return self.apply(
            walletEngineResourceStatus(snapshot.accountResource),
            account: snapshot.account,
            current: current,
            lastSuccessfulAt: lastSuccessfulAt,
            now: timestamp
        )
    }

    mutating func completeRefresh(
        id: UUID,
        update: WalletUpdate,
        current: WalletContext.Resource<Int64>,
        lastSuccessfulAt: Int32?,
        now: Int32
    ) -> (balance: WalletContext.Resource<Int64>, refreshed: Bool) {
        guard self.refresh?.id == id else { return (current, false) }
        defer { self.refresh = nil }
        let snapshot = update.snapshot
        let observation = Observation(account: snapshot.account, resource: snapshot.accountResource)
        if let latestRevision = self.latestRevision,
           snapshot.revision < latestRevision, observation != self.observation {
            return (current, false)
        }
        self.latestRevision = max(self.latestRevision ?? 0, snapshot.revision)
        self.observation = observation
        let status = walletEngineResourceStatus(snapshot.accountResource, outcome: update.outcome)
        let balance = self.apply(
            status,
            account: snapshot.account,
            current: current,
            lastSuccessfulAt: lastSuccessfulAt,
            now: now
        )
        let refreshed = status == .ready
            && snapshot.account.flatMap({ walletEngineBalance($0.balanceNanograms) }) != nil
        return (balance, refreshed)
    }

    mutating func failRefresh(
        id: UUID,
        error: Error,
        current: WalletContext.Resource<Int64>,
        lastSuccessfulAt: Int32?
    ) -> WalletContext.Resource<Int64> {
        guard self.refresh?.id == id else { return current }
        defer { self.refresh = nil }
        return self.apply(
            error is CancellationError ? .cancelled : .failed(synchronizationError(error)),
            account: nil,
            current: current,
            lastSuccessfulAt: lastSuccessfulAt,
            now: 0
        )
    }

    private mutating func apply(
        _ status: WalletEngineResourceStatus,
        account: AccountSnapshot?,
        current: WalletContext.Resource<Int64>,
        lastSuccessfulAt: Int32?,
        now: Int32
    ) -> WalletContext.Resource<Int64> {
        if case .loading = current {
            if self.stableBalance == nil {
                self.stableBalance = current.currentValue.map {
                    .value($0, updatedAt: lastSuccessfulAt ?? 0)
                } ?? .idle
            }
        } else {
            self.stableBalance = current
        }
        let balance: WalletContext.Resource<Int64>
        switch status {
        case .idle, .cancelled, .skipped:
            balance = self.stableBalance ?? .idle
        case .loading:
            return .loading(previous: current.currentValue)
        case .ready:
            guard let account, let value = walletEngineBalance(account.balanceNanograms) else {
                return self.apply(.failed(.invalidData), account: nil, current: current, lastSuccessfulAt: lastSuccessfulAt, now: now)
            }
            let timestamp = self.refresh?.publishedSuccess == true ? (lastSuccessfulAt ?? now) : now
            self.refresh?.publishedSuccess = true
            balance = .value(value, updatedAt: timestamp)
        case let .failed(error):
            balance = .stale(previous: current.currentValue, error: error, lastSuccessfulAt: lastSuccessfulAt)
        }
        self.stableBalance = balance
        return balance
    }
}
