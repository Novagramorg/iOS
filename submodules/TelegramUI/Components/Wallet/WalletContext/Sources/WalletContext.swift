import Foundation
import SwiftSignalKit

private let walletTransactionFetchLimit = 30

public final class WalletContext {
    public struct State: Equatable {
        public let balance: Int64?
        public let transactions: [Transaction]
        public let isLoading: Bool
        public let loadError: LoadError?
    }

    public struct Transaction: Equatable {
        public enum Direction: Equatable {
            case incoming
            case outgoing
            case unknown
        }

        public let id: String
        public let logicalTime: String
        public let timestamp: Int32
        public let direction: Direction
        public let amount: Int64
        public let fee: Int64
        public let counterparty: String?
        public let comment: String?
    }

    public struct LoadError: Equatable {
        public enum Request: Equatable {
            case balance
            case transactions
        }

        public enum Reason: Equatable {
            case transport
            case invalidResponse
            case httpStatus(Int)
            case api(code: Int?, message: String?)
            case invalidData
        }

        public let request: Request
        public let reason: Reason
    }

    public let address: String

    public var state: Signal<State, NoError> {
        return self.statePromise.get()
    }

    private var currentState: State
    private let statePromise: ValuePromise<State>
    private let loadDisposable = MetaDisposable()
    private var isActivated = false

    public init(address: String) {
        self.address = canonicalNonBounceableTonAddress(address) ?? address

        let initialState = State(
            balance: 0,
            transactions: [],
            isLoading: false,
            loadError: nil
        )
        self.currentState = initialState
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)
    }

    deinit {
        self.loadDisposable.dispose()
    }

    public func activate() {
        assert(Queue.mainQueue().isCurrent())

        guard !self.isActivated else {
            return
        }
        self.isActivated = true

        self.reload()
    }

    public func reload() {
        assert(Queue.mainQueue().isCurrent())

        guard !self.currentState.isLoading else {
            return
        }

        self.updateState(State(
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            isLoading: true,
            loadError: nil
        ))

        self.loadDisposable.set((walletLoadSignal(address: self.address)
        |> deliverOnMainQueue).start(next: { [weak self] event in
            guard let self else {
                return
            }

            switch event {
            case let .balance(result):
                switch result {
                case let .success(value):
                    guard let balance = Int64(value) else {
                        self.updateLoadError(request: .balance, error: .invalidData)
                        return
                    }
                    self.updateState(State(
                        balance: balance,
                        transactions: self.currentState.transactions,
                        isLoading: true,
                        loadError: self.currentState.loadError
                    ))
                case let .failure(error):
                    self.updateLoadError(request: .balance, error: error)
                }
            case let .transactions(result):
                switch result {
                case let .success(value):
                    guard let transactions = walletTransactions(from: value) else {
                        self.updateLoadError(request: .transactions, error: .invalidData)
                        return
                    }
                    self.updateState(State(
                        balance: self.currentState.balance,
                        transactions: transactions,
                        isLoading: true,
                        loadError: self.currentState.loadError
                    ))
                case let .failure(error):
                    self.updateLoadError(request: .transactions, error: error)
                }
            }
        }, completed: { [weak self] in
            guard let self else {
                return
            }
            self.updateState(State(
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                isLoading: false,
                loadError: self.currentState.loadError
            ))
        }))
    }

    private func updateLoadError(request: LoadError.Request, error: WalletRequestError) {
        self.updateState(State(
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            isLoading: true,
            loadError: LoadError(request: request, reason: loadErrorReason(error))
        ))
    }

    private func updateState(_ state: State) {
        assert(Queue.mainQueue().isCurrent())

        if self.currentState != state {
            self.currentState = state
            self.statePromise.set(state)
        }
    }
}

private enum WalletRequestError: Error {
    case transport
    case invalidResponse
    case httpStatus(Int)
    case api(code: Int?, message: String?)
    case invalidData
}

private enum WalletLoadEvent {
    case balance(Result<String, WalletRequestError>)
    case transactions(Result<[ToncenterTransaction], WalletRequestError>)
}

private struct ToncenterEnvelope<ResultValue: Decodable>: Decodable {
    let ok: Bool
    let result: ResultValue?
    let code: Int?
    let error: String?
}

private struct ToncenterTransaction: Decodable {
    struct Identifier: Decodable {
        let logicalTime: String
        let hash: String

        enum CodingKeys: String, CodingKey {
            case logicalTime = "lt"
            case hash
        }
    }

    struct Message: Decodable {
        let source: String?
        let destination: String?
        let value: String
        let message: String?
    }

    let timestamp: Int32
    let identifier: Identifier
    let fee: String
    let incomingMessage: Message?
    let outgoingMessages: [Message]

    enum CodingKeys: String, CodingKey {
        case timestamp = "utime"
        case identifier = "transaction_id"
        case fee
        case incomingMessage = "in_msg"
        case outgoingMessages = "out_msgs"
    }
}

private func walletLoadSignal(address: String) -> Signal<WalletLoadEvent, NoError> {
    let balanceSignal: Signal<Result<String, WalletRequestError>, NoError> = toncenterRequest(
        method: "getAddressBalance",
        queryItems: [URLQueryItem(name: "address", value: address)],
        resultType: String.self
    )

    return balanceSignal
    |> mapToSignal { balanceResult -> Signal<WalletLoadEvent, NoError> in
        let transactionSignal: Signal<WalletLoadEvent, NoError> = (Signal<Void, NoError>.single(Void())
        |> delay(1.1, queue: Queue.concurrentDefaultQueue())
        |> mapToSignal { _ -> Signal<Result<[ToncenterTransaction], WalletRequestError>, NoError> in
            return toncenterRequest(
                method: "getTransactions",
                queryItems: [
                    URLQueryItem(name: "address", value: address),
                    URLQueryItem(name: "limit", value: String(walletTransactionFetchLimit)),
                    URLQueryItem(name: "archival", value: "false")
                ],
                resultType: [ToncenterTransaction].self
            )
        }
        |> map { result in
            return WalletLoadEvent.transactions(result)
        })

        return Signal<WalletLoadEvent, NoError>.single(.balance(balanceResult))
        |> then(transactionSignal)
    }
}

private func toncenterRequest<ResultValue: Decodable>(
    method: String,
    queryItems: [URLQueryItem],
    resultType: ResultValue.Type
) -> Signal<Result<ResultValue, WalletRequestError>, NoError> {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "toncenter.com"
    components.path = "/api/v2/\(method)"
    components.queryItems = queryItems

    guard let url = components.url else {
        return .single(.failure(.invalidData))
    }

    return Signal { subscriber in
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                subscriber.putNext(.failure(.transport))
                subscriber.putCompletion()
                return
            }

            guard let response = response as? HTTPURLResponse else {
                subscriber.putNext(.failure(.invalidResponse))
                subscriber.putCompletion()
                return
            }
            guard (200 ..< 300).contains(response.statusCode) else {
                subscriber.putNext(.failure(.httpStatus(response.statusCode)))
                subscriber.putCompletion()
                return
            }
            guard let data else {
                subscriber.putNext(.failure(.invalidData))
                subscriber.putCompletion()
                return
            }

            do {
                let envelope = try JSONDecoder().decode(ToncenterEnvelope<ResultValue>.self, from: data)
                guard envelope.ok else {
                    subscriber.putNext(.failure(.api(code: envelope.code, message: envelope.error)))
                    subscriber.putCompletion()
                    return
                }
                guard let result = envelope.result else {
                    subscriber.putNext(.failure(.invalidData))
                    subscriber.putCompletion()
                    return
                }
                subscriber.putNext(.success(result))
                subscriber.putCompletion()
            } catch {
                subscriber.putNext(.failure(.invalidData))
                subscriber.putCompletion()
            }
        }
        task.resume()

        return ActionDisposable {
            task.cancel()
        }
    }
}

private func walletTransactions(from transactions: [ToncenterTransaction]) -> [WalletContext.Transaction]? {
    var result: [WalletContext.Transaction] = []
    result.reserveCapacity(transactions.count)

    for transaction in transactions {
        guard !transaction.identifier.hash.isEmpty,
              !transaction.identifier.logicalTime.isEmpty,
              let fee = Int64(transaction.fee) else {
            return nil
        }

        let incomingValue: Int64?
        if let incomingMessage = transaction.incomingMessage {
            guard let value = Int64(incomingMessage.value) else {
                return nil
            }
            incomingValue = value
        } else {
            incomingValue = nil
        }

        var outgoingValues: [Int64] = []
        outgoingValues.reserveCapacity(transaction.outgoingMessages.count)
        for message in transaction.outgoingMessages {
            guard let value = Int64(message.value) else {
                return nil
            }
            outgoingValues.append(value)
        }

        let direction: WalletContext.Transaction.Direction
        let amount: Int64
        let counterparty: String?
        let comment: String?
        if let incomingMessage = transaction.incomingMessage, let incomingValue, incomingValue != 0 {
            direction = .incoming
            amount = incomingValue
            counterparty = canonicalTonCounterparty(incomingMessage.source)
            comment = nonEmptyString(incomingMessage.message)
        } else if let index = outgoingValues.firstIndex(where: { $0 != 0 }) {
            let outgoingMessage = transaction.outgoingMessages[index]
            direction = .outgoing
            amount = outgoingValues[index]
            counterparty = canonicalTonCounterparty(outgoingMessage.destination)
            comment = nonEmptyString(outgoingMessage.message)
        } else {
            direction = .unknown
            amount = 0
            counterparty = nil
            comment = nil
        }

        result.append(WalletContext.Transaction(
            id: transaction.identifier.hash,
            logicalTime: transaction.identifier.logicalTime,
            timestamp: transaction.timestamp,
            direction: direction,
            amount: amount,
            fee: fee,
            counterparty: counterparty,
            comment: comment
        ))
    }

    return result
}

private func nonEmptyString(_ value: String?) -> String? {
    guard let value, !value.isEmpty else {
        return nil
    }
    return value
}

private func canonicalTonCounterparty(_ value: String?) -> String? {
    guard let value = nonEmptyString(value) else {
        return nil
    }
    return canonicalNonBounceableTonAddress(value)
}

private func canonicalNonBounceableTonAddress(_ address: String) -> String? {
    var payload: [UInt8]
    let isTestOnly: Bool
    if let friendlyAddress = decodeFriendlyTonAddress(address) {
        payload = Array(friendlyAddress.prefix(34))
        isTestOnly = (friendlyAddress[0] & 0x80) != 0
    } else if let rawAddress = decodeRawTonAddress(address) {
        payload = rawAddress
        isTestOnly = false
    } else {
        return nil
    }

    payload[0] = 0x51 | (isTestOnly ? 0x80 : 0x00)
    let checksum = tonAddressCrc16(payload)
    payload.append(UInt8(checksum >> 8))
    payload.append(UInt8(checksum & 0xff))

    return Data(payload).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func decodeFriendlyTonAddress(_ address: String) -> [UInt8]? {
    guard address.utf8.count == 48 else {
        return nil
    }

    let base64 = address
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    guard let data = Data(base64Encoded: base64), data.count == 36 else {
        return nil
    }

    let bytes = [UInt8](data)
    guard (bytes[0] & 0x3f) == 0x11 else {
        return nil
    }

    let checksum = tonAddressCrc16(Array(bytes.prefix(34)))
    guard bytes[34] == UInt8(checksum >> 8), bytes[35] == UInt8(checksum & 0xff) else {
        return nil
    }
    return bytes
}

private func decodeRawTonAddress(_ address: String) -> [UInt8]? {
    let components = address.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count == 2,
          let workchainValue = Int16(String(components[0])),
          workchainValue >= Int16(Int8.min),
          workchainValue <= Int16(Int8.max) else {
        return nil
    }

    let accountId = Array(components[1].utf8)
    guard accountId.count == 64 else {
        return nil
    }

    var payload: [UInt8] = [0x51, UInt8(bitPattern: Int8(workchainValue))]
    payload.reserveCapacity(34)
    for index in stride(from: 0, to: accountId.count, by: 2) {
        guard let high = tonHexValue(accountId[index]), let low = tonHexValue(accountId[index + 1]) else {
            return nil
        }
        payload.append((high << 4) | low)
    }
    return payload
}

private func tonHexValue(_ value: UInt8) -> UInt8? {
    switch value {
    case 48 ... 57:
        return value - 48
    case 65 ... 70:
        return value - 65 + 10
    case 97 ... 102:
        return value - 97 + 10
    default:
        return nil
    }
}

private func tonAddressCrc16(_ bytes: [UInt8]) -> UInt16 {
    var result: UInt32 = 0
    for byte in bytes {
        result ^= UInt32(byte) << 8
        for _ in 0 ..< 8 {
            if (result & 0x8000) != 0 {
                result = ((result << 1) ^ 0x1021) & 0xffff
            } else {
                result = (result << 1) & 0xffff
            }
        }
    }
    return UInt16(result)
}

private func loadErrorReason(_ error: WalletRequestError) -> WalletContext.LoadError.Reason {
    switch error {
    case .transport:
        return .transport
    case .invalidResponse:
        return .invalidResponse
    case let .httpStatus(statusCode):
        return .httpStatus(statusCode)
    case let .api(code, message):
        return .api(code: code, message: message)
    case .invalidData:
        return .invalidData
    }
}
