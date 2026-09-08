import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

final class WalletContextOutput {
    private let stateValue: Atomic<WalletContext.State>
    let statePromise: ValuePromise<WalletContext.State>
    let tonConnectPresentationPipe = ValuePipe<WalletContext.TonConnectPresentation>()
    private let cancelOperationImpl: (UUID) -> Void

    init(initialState: WalletContext.State, cancelOperation: @escaping (UUID) -> Void) {
        self.stateValue = Atomic(value: initialState)
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)
        self.cancelOperationImpl = cancelOperation
    }

    func publish(state: WalletContext.State) {
        _ = self.stateValue.swap(state)
        self.statePromise.set(state)
    }

    func currentState() -> WalletContext.State {
        self.stateValue.with { $0 }
    }

    func publish(presentation: WalletContext.TonConnectPresentation) {
        self.tonConnectPresentationPipe.putNext(presentation)
    }

    func cancelOperation(id: UUID) {
        self.cancelOperationImpl(id)
    }
}

private struct WalletSubscriberDemand: Sendable {
    var count: Int = 0
    var revision: UInt64 = 0
}

struct WalletScreenDemand: Sendable {
    var walletCount = 0
    var collectiblesCount = 0
    var walletOpenRevision: UInt64 = 0
    var collectiblesOpenRevision: UInt64 = 0
    var balanceRequests = Set<UUID>()
    var revision: UInt64 = 0

    var visibleScope: WalletSynchronizationScope {
        if self.walletCount > 0 {
            return .all
        }
        if self.collectiblesCount > 0 {
            return .nfts
        }
        return []
    }

    func openedScope(since previous: WalletScreenDemand) -> WalletSynchronizationScope {
        guard self.revision > previous.revision else { return [] }
        var scope: WalletSynchronizationScope = []
        if self.walletCount > 0, self.walletOpenRevision > previous.walletOpenRevision {
            scope = .all
        }
        if self.collectiblesCount > 0, self.collectiblesOpenRevision > previous.collectiblesOpenRevision {
            scope.insert(.nfts)
        }
        if !self.balanceRequests.subtracting(previous.balanceRequests).isEmpty {
            scope.insert(.account)
        }
        return scope
    }
}

public final class WalletContext {
    static let useWalletTransferApi = false

    let impl: WalletContextImpl
    let logger: WalletLogger
    private let output: WalletContextOutput
    private let environmentDisposable = MetaDisposable()
    private let walletConfigurationDisposable = MetaDisposable()
    private let walletStateUpdatesDisposable = MetaDisposable()
    private let storedStateDisposable = MetaDisposable()
    private let twoStepAuthDisposable = MetaDisposable()
    private let operationTaskRegistry: WalletOperationTaskRegistry
    private let environmentRevision = Atomic<UInt64>(value: 0)
    private let walletConfigurationRevision = Atomic<UInt64>(value: 0)
    private let walletStateRevision = Atomic<UInt64>(value: 0)
    private let twoStepAuthRevision = Atomic<UInt64>(value: 0)
    private let subscriberDemand = Atomic<WalletSubscriberDemand>(value: WalletSubscriberDemand())
    private let walletScreenDemand = Atomic<WalletScreenDemand>(value: WalletScreenDemand())
    let fiatCurrencyRevision = Atomic<UInt64>(value: 0)

    public var state: Signal<State, NoError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let impl = self.impl
            let subscriberDemand = self.subscriberDemand
            let demand = subscriberDemand.modify { value in
                var value = value
                value.count += 1
                value.revision &+= 1
                return value
            }
            Task {
                await impl.updateStateSubscriberDemand(count: demand.count, revision: demand.revision)
            }
            let disposable = (self.output.statePromise.get()
            |> deliverOnMainQueue).start(next: subscriber.putNext)
            return ActionDisposable {
                disposable.dispose()
                let demand = subscriberDemand.modify { value in
                    var value = value
                    value.count = max(0, value.count - 1)
                    value.revision &+= 1
                    return value
                }
                Task {
                    await impl.updateStateSubscriberDemand(count: demand.count, revision: demand.revision)
                }
            }
        }
    }

    public var stateValue: State {
        self.output.currentState()
    }

    public var tonConnectPresentations: Signal<TonConnectPresentation, NoError> {
        self.output.tonConnectPresentationPipe.signal()
        |> deliverOnMainQueue
    }

    public func beginWalletScreenUpdates() -> Disposable {
        return self.beginScreenUpdates(collectiblesOnly: false)
    }

    public func beginCollectiblesScreenUpdates() -> Disposable {
        return self.beginScreenUpdates(collectiblesOnly: true)
    }

    public func refreshBalance() -> Disposable {
        let id = UUID()
        self.updateScreenDemand { $0.balanceRequests.insert(id) }
        return ActionDisposable { [weak self] in
            self?.updateScreenDemand { $0.balanceRequests.remove(id) }
        }
    }

    private func beginScreenUpdates(collectiblesOnly: Bool) -> Disposable {
        self.updateScreenDemand {
            if collectiblesOnly {
                $0.collectiblesCount += 1
                $0.collectiblesOpenRevision &+= 1
            } else {
                $0.walletCount += 1
                $0.walletOpenRevision &+= 1
            }
        }
        return ActionDisposable { [weak self] in
            self?.updateScreenDemand {
                if collectiblesOnly {
                    $0.collectiblesCount -= 1
                } else {
                    $0.walletCount -= 1
                }
            }
        }
    }

    private func updateScreenDemand(_ update: (inout WalletScreenDemand) -> Void) {
        let demand = self.walletScreenDemand.modify { value in
            var value = value
            update(&value)
            value.revision &+= 1
            return value
        }
        let impl = self.impl
        Task {
            await impl.updateWalletScreenDemand(demand)
        }
    }

    public init(
        engine: TelegramEngine,
        storageNamespace: String,
        applicationInForeground: Signal<Bool, NoError>,
        accountIsCurrent: Signal<Bool, NoError>,
        networkAvailable: Signal<Bool, NoError>,
        twoStepAuthRequired: Signal<Bool?, NoError> = .single(nil),
        log: @escaping (String) -> Void = { Logger.shared.log("WalletContext", $0) }
    ) {
        let initialState = State(
            phase: .restoring,
            balance: .idle,
            transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            pendingTransfers: [],
            activeOperation: nil
        )
        let operationTaskRegistry = WalletOperationTaskRegistry()
        let output = WalletContextOutput(
            initialState: initialState,
            cancelOperation: { operationTaskRegistry.cancel(id: $0) }
        )
        let logger = WalletLogger(log)
        let impl = WalletContextImpl(
            engine: engine,
            storageNamespace: storageNamespace,
            initialState: initialState,
            output: output,
            logger: logger
        )
        self.output = output
        self.logger = logger
        self.impl = impl
        self.operationTaskRegistry = operationTaskRegistry

        self.walletConfigurationDisposable.set((engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> map { WalletConfiguration.with(appConfiguration: $0).transferMinAmount }
        |> distinctUntilChanged).start(next: { [weak self] transferMinAmount in
            guard let self else { return }
            let revision = self.walletConfigurationRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.updateWalletConfiguration(transferMinAmount: transferMinAmount, revision: revision)
            }
        }))

        self.walletStateUpdatesDisposable.set(engine.wallet.stateUpdates().start(next: { [weak self] value in
            guard let self else { return }
            let revision = self.walletStateRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.receiveServerWalletState(value, revision: revision)
            }
        }))

        self.twoStepAuthDisposable.set(twoStepAuthRequired.start(next: { [weak self] value in
            guard let self else { return }
            let revision = self.twoStepAuthRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.updateTwoStepAuthRequirement(value, revision: revision)
            }
        }))

        self.environmentDisposable.set(combineLatest(
            applicationInForeground |> distinctUntilChanged,
            accountIsCurrent |> distinctUntilChanged,
            networkAvailable |> distinctUntilChanged
        ).start(next: { [weak self] foreground, current, network in
            guard let self else { return }
            let revision = self.environmentRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.updateEnvironment(
                    foreground: foreground,
                    accountIsCurrent: current,
                    networkAvailable: network,
                    revision: revision
                )
            }
        }))

        self.storedStateDisposable.set((engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(
                key: ApplicationSpecificPreferencesKeys.walletState
            )
        )).start(next: { entry in
            let storedState: WalletStoredState?
            let isInvalid: Bool
            if let entry {
                if let value = entry.get(WalletStoredState.self),
                   value.schemaVersion == WalletStoredState.currentSchemaVersion {
                    storedState = value
                    isInvalid = false
                } else {
                    storedState = nil
                    isInvalid = true
                }
            } else {
                storedState = nil
                isInvalid = false
            }
            Task {
                await impl.restoreStoredState(storedState, removeInvalidEntry: isInvalid)
            }
        }))
    }

    deinit {
        self.environmentDisposable.dispose()
        self.walletConfigurationDisposable.dispose()
        self.walletStateUpdatesDisposable.dispose()
        self.storedStateDisposable.dispose()
        self.twoStepAuthDisposable.dispose()
        self.operationTaskRegistry.shutdown()
        let impl = self.impl
        Task {
            await impl.shutdown()
        }
    }

    func signal<Value: Sendable>(
        name: String,
        cancelOnDispose: Bool = true,
        operation: @escaping @Sendable (WalletContextImpl, UUID) async throws -> Value
    ) -> Signal<Value, WalletError> {
        let source = Signal<Value, WalletError> { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let operationId = UUID()
            let cancellation = WalletOperationCancellation()
            let registry = self.operationTaskRegistry
            let logger = self.logger
            let impl = self.impl
            registry.register(id: operationId, cancellation: cancellation)
            let task = Task {
                defer {
                    registry.remove(id: operationId)
                }
                do {
                    let value = try await operation(impl, operationId)
                    try Task.checkCancellation()
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                } catch let error as CancellationError {
                    logger.error("wallet_operation_cancelled", error, context: "operation=\(name)")
                    subscriber.putError(.unavailable)
                } catch {
                    logger.error("wallet_operation_failed", error, context: "operation=\(name)")
                    subscriber.putError(walletError(error))
                }
            }
            cancellation.setTask(task)
            return ActionDisposable {
                if cancelOnDispose {
                    registry.cancel(id: operationId)
                }
            }
        }
        return source |> deliverOnMainQueue
    }

    func noErrorSignal(
        operation: @escaping @Sendable (WalletContextImpl) async -> Void
    ) -> Signal<Void, NoError> {
        let impl = self.impl
        let source = Signal<Void, NoError> { subscriber in
            let task = Task {
                await operation(impl)
                guard !Task.isCancelled else { return }
                subscriber.putNext(Void())
                subscriber.putCompletion()
            }
            return ActionDisposable { task.cancel() }
        }
        return source |> deliverOnMainQueue
    }
}

public struct WalletConfiguration {
    public static var defaultValue: WalletConfiguration {
        return WalletConfiguration(
            transferMinAmount: 100_000_000,
            transferGaslessMinAmount: 100_000_000
        )
    }

    public let transferMinAmount: Int64
    public let transferGaslessMinAmount: Int64

    private init(
        transferMinAmount: Int64,
        transferGaslessMinAmount: Int64
    ) {
        self.transferMinAmount = transferMinAmount
        self.transferGaslessMinAmount = transferGaslessMinAmount
    }

    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        var transferMinAmount = self.defaultValue.transferMinAmount
        if let value = appConfiguration.data?["wallet_transfer_min_nanos"] as? Double,
           let intValue = Int64(exactly: value) {
            transferMinAmount = intValue
        }
        var transferGaslessMinAmount = self.defaultValue.transferGaslessMinAmount
        if let value = appConfiguration.data?["wallet_gasless_min_nanos"] as? Double,
           let intValue = Int64(exactly: value), intValue >= 0 {
            transferGaslessMinAmount = intValue
        }
        return WalletConfiguration(
            transferMinAmount: transferMinAmount,
            transferGaslessMinAmount: transferGaslessMinAmount
        )
    }
}
