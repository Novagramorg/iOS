import Foundation

enum DefaultCryptoProvider {
    static func signing() -> any Ed25519Signing {
        #if canImport(_TONCryptoBoringSSL)
        return BoringSSLProvider()
        #else
        return TweetNaClProvider()
        #endif
    }

    static func keyExchange() -> any KeyExchanging {
        #if canImport(_TONCryptoBoringSSL)
        return BoringSSLProvider()
        #else
        return TweetNaClProvider()
        #endif
    }
}
