//
//  TONWalletKitConfiguration.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 07.10.2025.
//
//  Copyright (c) 2025 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

#if os(iOS)
import UIKit
#endif

public struct TONToncenterRequest: Sendable {
    public enum Method: String, Sendable {
        case get
        case post
    }

    public let method: Method
    public let endpoint: String
    public let query: String?
    public let payload: String?

    public init(
        method: Method,
        endpoint: String,
        query: String? = nil,
        payload: String? = nil
    ) {
        self.method = method
        self.endpoint = endpoint
        self.query = query
        self.payload = payload
    }
}

public struct TONWalletKitConfiguration: Encodable, Hashable {
    public typealias FetchManifest = (_ manifestUrl: String) async throws -> TONManifestFetchResult

    let networkConfigurations: [NetworkConfiguration]
    let deviceInfo: DeviceInfo
    let walletManifest: Manifest
    let storage: TONWalletKitStorageType
    let sessionManager: (any TONConnectSessionsManager)?
    let bridge: Bridge?
    let eventsConfiguration: EventsConfiguration?
    let devConfiguration: DevConfiguration?
    let analyticsConfiguration: AnalyticsConfiguration?
    public var fetchManifest: FetchManifest?

    public init(
        networkConfigurations: Set<NetworkConfiguration>,
        walletManifest: Manifest,
        storage: TONWalletKitStorageType = .keychain,
        sessionManager: (any TONConnectSessionsManager)? = nil,
        bridge: Bridge?,
        eventsConfiguration: EventsConfiguration? = nil,
        features: [any TONFeature],
        devConfiguration: DevConfiguration? = nil,
        analyticsConfiguration: AnalyticsConfiguration? = nil
    ) {
        self.networkConfigurations = Array(networkConfigurations)

        let rawFeatures = features.compactMap(\.raw)

        self.deviceInfo = DeviceInfo(
            appName: walletManifest.appName,
            features: rawFeatures
        )

        var manifest = walletManifest
        manifest.features = rawFeatures

        self.walletManifest = manifest
        self.storage = storage
        self.sessionManager = sessionManager
        self.bridge = bridge
        self.eventsConfiguration = eventsConfiguration
        self.devConfiguration = devConfiguration
        self.analyticsConfiguration = analyticsConfiguration
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            networkConfigurations.filter {
                $0.apiClientConfiguration != nil
            },
            forKey: .networkConfigurations)
        try container.encode(deviceInfo, forKey: .deviceInfo)
        try container.encode(walletManifest, forKey: .walletManifest)
        try container.encodeIfPresent(bridge, forKey: .bridge)
        try container.encodeIfPresent(eventsConfiguration, forKey: .eventsConfiguration)
        try container.encodeIfPresent(devConfiguration, forKey: .devConfiguration)
        try container.encodeIfPresent(analyticsConfiguration, forKey: .analytics)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(networkConfigurations)
        hasher.combine(deviceInfo)
        hasher.combine(walletManifest)
        hasher.combine(bridge)
        hasher.combine(eventsConfiguration)
        hasher.combine(devConfiguration)
        hasher.combine(analyticsConfiguration)
    }
    
    public static func == (lhs: TONWalletKitConfiguration, rhs: TONWalletKitConfiguration) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    
    enum CodingKeys: String, CodingKey {
        case networkConfigurations
        case deviceInfo
        case walletManifest
        case bridge
        case eventsConfiguration
        case devConfiguration = "dev"
        case analytics
    }
}

extension TONWalletKitConfiguration {
    
    public struct DevConfiguration: Encodable, Hashable {
        let disableNetworkSend: Bool?
        let disableManifestDomainCheck: Bool?
        
        public init(
            disableNetworkSend: Bool? = nil,
            disableManifestDomainCheck: Bool? = nil
        ) {
            self.disableNetworkSend = disableNetworkSend
            self.disableManifestDomainCheck = disableManifestDomainCheck
        }
    }
    
    public struct AnalyticsConfiguration: Encodable, Hashable {
        let analyticsEnabled: Bool?
        
        public init(analyticsEnabled: Bool? = nil) {
            self.analyticsEnabled = analyticsEnabled
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(analyticsEnabled, forKey: .analyticsEnabled)
        }
        
        enum CodingKeys: String, CodingKey {
            case analyticsEnabled = "enabled"
        }
    }
    
    public struct EventsConfiguration: Encodable, Hashable {
        let disableEvents: Bool
        let disableTransactionEmulation: Bool
        
        public init(disableEvents: Bool = false, disableTransactionEmulation: Bool = false) {
            self.disableEvents = disableEvents
            self.disableTransactionEmulation = disableTransactionEmulation
        }
    }
    
    public struct NetworkConfiguration: Encodable, Hashable {
        let network: TONNetwork
        let apiClientConfiguration: APIClientConfiguration?
        let apiClient: APIClient?
        
        public init(network: TONNetwork, apiClientConfiguration: APIClientConfiguration) {
            self.network = network
            self.apiClientConfiguration = apiClientConfiguration
            self.apiClient = nil
        }
        
        public init(network: TONNetwork, apiClient: APIClient) {
            self.network = network
            self.apiClient = apiClient
            self.apiClientConfiguration = apiClient.configuration
        }
        
        public init(network: TONNetwork, apiClient: TONAPIClient) {
            self = Self(network: network, apiClient: .custom(apiClient))
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(network)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(network, forKey: .network)
            
            switch apiClient {
            case .custom:
                try container.encode(APIClientType.custom, forKey: .apiClientType)
            case .toncenter:
                try container.encode(APIClientType.toncenter, forKey: .apiClientType)
            case .tonApi:
                try container.encode(APIClientType.tonapi, forKey: .apiClientType)
            case nil:
                try container.encode(APIClientType.default, forKey: .apiClientType)
            }
            
            try container.encode(apiClientConfiguration, forKey: .apiClientConfiguration)
        }
        
        public static func == (lhs: NetworkConfiguration, rhs: NetworkConfiguration) -> Bool {
            return lhs.network == rhs.network
        }
        
        enum CodingKeys: String, CodingKey {
            case network
            case apiClientConfiguration
            case apiClientType
        }
    }
    
    public enum APIClient {
        case custom(TONAPIClient)
        case toncenter(APIClientConfiguration)
        case tonApi(APIClientConfiguration)
        
        var configuration: APIClientConfiguration? {
            switch self {
            case .custom: nil
            case .toncenter(let config), .tonApi(let config): config
            }
        }
    }
    
    enum APIClientType: String, Encodable {
        case `default`
        case toncenter
        case tonapi
        case custom
    }
    
    struct DeviceInfo: Codable, Hashable {
        let platform: String
        let appName: String
        let appVersion: String
        
        // Currently just a constant
        private var maxProtocolVersion: Int = 2
        let features: [TONRawFeature]
        
        init(appName: String, features: [TONRawFeature]) {
#if os(iOS)
            self.platform = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
#else
            self.platform = "unknown"
#endif
            self.appName = appName
            self.appVersion = Bundle.main.appVersion
            self.features = features
        }
    }
    
    public struct Manifest: Codable, Hashable {
        let name: String
        let appName: String
        let imageUrl: String
        let tondns: String?
        let aboutUrl: String
        private var platforms = ["ios"]
        
        let universalLink: String
        let deepLink: String?
        let bridgeUrl: String
        
        var features: [TONRawFeature] = []
        
        public init(
            name: String,
            appName: String,
            imageUrl: String,
            tondns: String? = nil,
            aboutUrl: String,
            universalLink: String,
            deepLink: String? = nil,
            bridgeUrl: String
        ) {
            self.name = name
            self.appName = appName
            self.imageUrl = imageUrl
            self.tondns = tondns
            self.aboutUrl = aboutUrl
            self.universalLink = universalLink
            self.deepLink = deepLink
            self.bridgeUrl = bridgeUrl
        }
    }
    
    public struct Bridge: Encodable, Hashable {
        let bridgeUrl: String
        let webViewInjectionKey: String?
        
        let heartbeatInterval: TimeInterval?
        let reconnectInterval: TimeInterval?
        let maxReconnectAttempts: Int?
        
        public init(
            bridgeUrl: String,
            webViewInjectionKey: String? = nil,
            heartbeatInterval: TimeInterval? = nil,
            reconnectInterval: TimeInterval? = nil,
            maxReconnectAttempts: Int? = nil
        ) {
            self.bridgeUrl = bridgeUrl
            self.heartbeatInterval = heartbeatInterval
            self.reconnectInterval = reconnectInterval
            self.maxReconnectAttempts = maxReconnectAttempts
            self.webViewInjectionKey = webViewInjectionKey
        }
    }
    
    public struct APIClientConfiguration: Encodable, Hashable {
        public typealias RequestHandler = @Sendable (TONToncenterRequest) async throws -> String

        let url: URL?
        let key: String
        let timeout: TimeInterval?
        let disableNetworkSend: Bool?
        let dnsResolver: String?
        let requestHandler: RequestHandler?
        
        public init(
            url: URL? = nil,
            key: String,
            timeout: TimeInterval? = nil,
            disableNetworkSend: Bool? = nil,
            dnsResolver: String? = nil,
            requestHandler: RequestHandler? = nil
        ) {
            self.url = url
            self.key = key
            self.timeout = timeout
            self.disableNetworkSend = disableNetworkSend
            self.dnsResolver = dnsResolver
            self.requestHandler = requestHandler
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encode(key, forKey: .key)
            if let timeout {
                // Foundation exposes time intervals in seconds, while the JS clients
                // pass this value directly to setTimeout, which expects milliseconds.
                try container.encode(timeout * 1_000.0, forKey: .timeout)
            }
            try container.encodeIfPresent(disableNetworkSend, forKey: .disableNetworkSend)
            try container.encodeIfPresent(dnsResolver, forKey: .dnsResolver)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(key)
            hasher.combine(timeout)
            hasher.combine(disableNetworkSend)
            hasher.combine(dnsResolver)
        }

        public static func == (lhs: APIClientConfiguration, rhs: APIClientConfiguration) -> Bool {
            return lhs.url == rhs.url
                && lhs.key == rhs.key
                && lhs.timeout == rhs.timeout
                && lhs.disableNetworkSend == rhs.disableNetworkSend
                && lhs.dnsResolver == rhs.dnsResolver
        }

        private enum CodingKeys: String, CodingKey {
            case url
            case key
            case timeout
            case disableNetworkSend
            case dnsResolver
        }
    }
}

private extension Bundle {
    
    var appName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String ??
               "Unknown App"
    }
    
    var appVersion: String {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
