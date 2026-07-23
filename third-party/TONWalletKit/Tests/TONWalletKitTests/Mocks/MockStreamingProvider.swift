import Foundation
import Combine
@testable import TONWalletKit

class MockStreamingProvider: TONStreamingProviderProtocol {
    typealias Identifier = AnyTONProviderIdentifier

    var identifier = AnyTONProviderIdentifier(name: "mock-streaming")
    var network: TONNetwork = TONNetwork(chainId: "-239")

    var balanceSubject = PassthroughSubject<TONBalanceUpdate, any Error>()
    var transactionsSubject = PassthroughSubject<TONTransactionsUpdate, any Error>()
    var jettonsSubject = PassthroughSubject<TONJettonUpdate, any Error>()
    var connectionChangeSubject = PassthroughSubject<Bool, any Error>()

    var balanceCalledWith: String?
    var transactionsCalledWith: String?
    var jettonsCalledWith: String?
    var connectCalled = false
    var disconnectCalled = false

    func balance(address: String) -> AnyPublisher<TONBalanceUpdate, any Error> {
        balanceCalledWith = address
        return balanceSubject.eraseToAnyPublisher()
    }

    func transactions(address: String) -> AnyPublisher<TONTransactionsUpdate, any Error> {
        transactionsCalledWith = address
        return transactionsSubject.eraseToAnyPublisher()
    }

    func jettons(address: String) -> AnyPublisher<TONJettonUpdate, any Error> {
        jettonsCalledWith = address
        return jettonsSubject.eraseToAnyPublisher()
    }

    func connect() throws {
        connectCalled = true
    }

    func disconnect() throws {
        disconnectCalled = true
    }

    func connectionChange() -> AnyPublisher<Bool, any Error> {
        connectionChangeSubject.eraseToAnyPublisher()
    }
}
