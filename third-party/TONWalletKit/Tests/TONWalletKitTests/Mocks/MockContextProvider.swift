@testable import TONWalletKit

class MockContextProvider: TONWalletKitContextProviderProtocol {
    var mockContext: MockWalletKitContext?
    var shouldThrow = false
    var contextCallCount = 0

    func context(for configuration: TONWalletKitConfiguration) async throws -> any JSWalletKitContextProtocol {
        contextCallCount += 1
        if shouldThrow { throw "MockContextProvider error" }
        guard let mockContext else { throw "No mock context set" }
        return mockContext
    }
}
