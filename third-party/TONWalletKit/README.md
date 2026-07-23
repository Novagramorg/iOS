# TONWalletKit for iOS

A Swift Package that provides everything you need to build a TON wallet on Apple platforms: wallet
creation and import, balances, transfers, NFTs and jettons, TON Connect (dApp connections,
transaction / sign-message / sign-data requests), live streaming updates, and DeFi (swap, staking,
gasless).

The kit ships the official `@tonconnect/walletkit` JavaScript core embedded via `JavaScriptCore`
and exposes a fully typed, `async/await` Swift API on top of it — you never touch JS.

- **Platforms:** iOS 14+, macOS 11+
- **Language:** Swift 5 mode (Swift tools 6.2+)

## Table of contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Creating the kit](#creating-the-kit)
- [Storage](#storage)
- [Wallets](#wallets)
- [Reading balance & assets](#reading-balance--assets)
- [Sending TON](#sending-ton)
- [TON Connect](#ton-connect)
- [Streaming live updates](#streaming-live-updates)
- [DeFi: swap, staking, gasless](#defi-swap-staking-gasless)
- [Working with amounts & addresses](#working-with-amounts--addresses)
- [Error handling](#error-handling)
- [Development](#development)

## Installation

### Xcode

`File ▸ Add Package Dependencies…`, enter the repository URL:

```
https://github.com/ton-connect/kit-ios.git
```

then add the **TONWalletKit** product to your target.

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ton-connect/kit-ios.git", branch: "main")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["TONWalletKit"]
    )
]
```

```swift
import TONWalletKit
```

## Configuration

Everything starts with a `TONWalletKitConfiguration`. It describes the networks you support, your
wallet's TON Connect manifest, where keys are stored, the TON Connect bridge, and which TON Connect
features your wallet implements.

```swift
import TONWalletKit

let apiClientConfig = TONWalletKitConfiguration.APIClientConfiguration(
    key: "YOUR_TONCENTER_API_KEY"
)

let configuration = TONWalletKitConfiguration(
    // One entry per network you want to support.
    networkConfigurations: [
        TONWalletKitConfiguration.NetworkConfiguration(
            network: .mainnet,
            apiClient: .toncenter(apiClientConfig)
        ),
        TONWalletKitConfiguration.NetworkConfiguration(
            network: .testnet,
            apiClient: .toncenter(apiClientConfig)
        ),
    ],

    // Your TON Connect manifest — shown to dApps that connect to your wallet.
    walletManifest: TONWalletKitConfiguration.Manifest(
        name: "My TON Wallet",
        appName: "my_ton_wallet",
        imageUrl: "https://example.com/icon.png",
        aboutUrl: "https://example.com/about",
        universalLink: "https://example.com/ton-connect",
        bridgeUrl: "https://connect.ton.org/bridge"
    ),

    // Where private keys / sessions are persisted (see "Storage").
    storage: .keychain,

    // TON Connect bridge. Pass `nil` if you don't need TON Connect.
    bridge: TONWalletKitConfiguration.Bridge(
        bridgeUrl: "https://connect.ton.org/bridge"
    ),

    // The TON Connect capabilities your wallet supports.
    features: [
        TONSendTransactionFeature(maxMessages: 255),
        TONSignDataFeature(types: [.text, .binary, .cell]),
        TONEmbeddedRequestFeature(),
    ]
)
```

### API client per network

Each `NetworkConfiguration` picks how that network talks to the chain:

```swift
// TON Center (key required):
.init(network: .mainnet, apiClient: .toncenter(.init(key: "TONCENTER_KEY")))

// TON API:
.init(network: .mainnet, apiClient: .tonApi(.init(key: "TONAPI_KEY")))

// A fully custom client conforming to `TONAPIClient`:
.init(network: .mainnet, apiClient: myCustomClient)
```

`APIClientConfiguration` also accepts an optional `url`, `timeout`, `disableNetworkSend`, and
`dnsResolver`.

## Creating the kit

```swift
let kit = TONWalletKit(configuration: configuration)

// Optional: warm up the embedded JS core ahead of time.
try await kit.initialize()
```

`initialize()` is optional — every `async` method initializes the kit lazily on first use. Calling
it up front simply moves that one-time cost to a moment you control. `kit.isInitialized` tells you
the current state.

Hold on to a single, long-lived `TONWalletKit` instance for the lifetime of your app.

## Storage

Keys and TON Connect sessions are persisted through the `storage` you pass in the configuration:

```swift
.memory                // in-memory, lost on relaunch — good for tests/demos
.keychain              // persisted in the iOS/macOS Keychain (default, recommended)
.custom(myStorage)     // your own type conforming to `TONWalletKitStorage`
```

A custom backend implements the async `TONWalletKitStorage` protocol:

```swift
final class MyStorage: TONWalletKitStorage {
    func set(key: String, value: String) async throws { /* … */ }
    func get(key: String) async throws -> String? { /* … */ }
    func remove(key: String) async throws { /* … */ }
    func clear() async throws { /* … */ }
}
```

## Wallets

A wallet is created in two steps: build a **wallet adapter** (key material + contract version), then
**add** it to the kit to get a usable `TONWalletProtocol`.

### Create a brand-new wallet

`createWallet` generates a fresh mnemonic and a v5r1 adapter in one call:

```swift
let result = try await kit.createWallet(
    parameters: TONV5R1WalletParameters(network: .mainnet, domain: nil),
    mnemonicLength: .bits128 // 12 words; omit for the source-compatible 24-word default
)

// IMPORTANT: back this mnemonic up securely and show it to the user once.
let mnemonic: TONMnemonic = result.mnemonic

let wallet = try await kit.add(walletAdapter: result.walletAdapter)
print("New wallet:", wallet.address.value)
```

### Import from a mnemonic

```swift
let mnemonic = TONMnemonic(string: "word1 word2 … word24")   // 12 or 24 words

guard try await kit.validateMnemonic(mnemonic) else {
    throw TONWalletKitError.invalidMnemonic
}

let signer = try await kit.signer(mnemonic: mnemonic)
let adapter = try await kit.walletV5R1Adapter(
    signer: signer,
    parameters: TONV5R1WalletParameters(network: .mainnet, domain: nil)
)
let wallet = try await kit.add(walletAdapter: adapter)
```

Use `kit.walletV4R2Adapter(signer:parameters:)` with `TONV4R2WalletParameters` for v4r2 contracts.

### Import from a private key or an external signer

```swift
// From a raw 32-byte private key:
let signer = try await kit.signer(privateKey: privateKeyData)

// Or supply your own signer (e.g. a hardware/secure-enclave backed key):
final class MySigner: TONWalletSignerProtocol {
    func sign(data: Data) async throws -> TONHex { /* … */ }
    func publicKey() -> TONHex { /* … */ }
}
```

Either signer can then be passed to `walletV5R1Adapter` / `walletV4R2Adapter`.

### Generate a mnemonic only

```swift
let mnemonic = try await kit.generateMnemonic(length: .bits128) // or .bits256
```

### List, fetch, and remove

```swift
let wallets = try await kit.wallets()          // [any TONWalletProtocol]
let wallet  = try await kit.wallet(id: walletID)
try await kit.remove(walletId: walletID)
```

## Reading balance & assets

```swift
let address = wallet.address.value             // user-friendly string
let balance = try await wallet.balance()       // TONBalance (nano-units)

// Format nano-units into a human string:
let formatter = TONBalanceFormatter()
print("Balance:", formatter.string(from: balance) ?? "0", "TON")

// Jettons (tokens) and NFTs:
let jettons = try await wallet.jettons(limit: 50)
let nfts    = try await wallet.nfts(limit: 50)

let usdtBalance = try await wallet.jettonBalance(
    jettonAddress: try TONUserFriendlyAddress(value: "EQ…jettonMaster")
)
```

## Sending TON

Build a transfer, turn it into a transaction, then send it:

```swift
let request = TONTransferRequest(
    transferAmount: TONBalanceFormatter().amount(from: "1.5")!,   // 1.5 TON
    recipientAddress: try TONUserFriendlyAddress(value: "EQ…recipient"),
    comment: "Thanks!"
)

let transaction = try await wallet.transferTONTransaction(request: request)

// Optional: emulate before sending.
let preview = try await wallet.preview(transactionRequest: transaction)

let response = try await wallet.send(transactionRequest: transaction)
print("Sent. Normalized hash:", response.normalizedHash.value)
```

You can also send a prepared transaction through the kit:

```swift
try await kit.send(transaction: transaction, from: wallet)
```

Jetton and NFT transfers follow the same shape via
`wallet.transferJettonTransaction(request:)` and `wallet.transferNFTTransaction(request:)`.

## TON Connect

Your wallet acts as the TON Connect **wallet** side: a dApp asks to connect, then to sign or send.

### Handle a connection link

A `tc://`, universal, or deep link from a dApp is passed straight to `connect`:

```swift
try await kit.connect(url: "tc://connect?v=2&id=…")
```

The kit then delivers the resulting requests to your event handler.

### Register an event handler

```swift
import TONWalletKit

final class WalletEventsHandler: TONBridgeEventsHandler {
    func handle(event: TONWalletKitEvent) throws {
        switch event {
        case .connectRequest(let request):
            // Show approval UI, then approve with the wallet the user chose:
            Task {
                try await request.approve(walletId: chosenWalletID)
                // or: try await request.reject(reason: "User cancelled")
            }

        case .transactionRequest(let request):
            Task { _ = try await request.approve() }      // or request.reject(reason:)

        case .signMessageRequest(let request):
            Task { _ = try await request.approve() }

        case .signDataRequest(let request):
            Task { _ = try await request.approve() }

        case .disconnect(let event):
            print("dApp disconnected:", event)
        }
    }
}

let handler = WalletEventsHandler()
try kit.add(eventsHandler: handler)   // may be called before initialize(); it's queued
```

Each request exposes the dApp's intent on its `event` property (so you can render details for the
user) plus `approve(…)` / `reject(reason:)`. Approving a connection can return an **embedded**
follow-up request (e.g. a transaction to sign immediately) — `approve` returns the next
`TONWalletKitEvent?` for that case.

Call `kit.remove(eventsHandler:)` when the handler is no longer needed.

## Streaming live updates

Streaming pushes balance / jetton / transaction changes in real time over Combine publishers.
Register a streaming provider once, connect, then subscribe.

```swift
import Combine

let streaming = try await kit.streaming()

// Register a provider for the network you want to watch (once):
let provider = try await kit.streamingProvider(
    config: TONTonCenterStreamingProviderConfig(
        network: .mainnet,
        apiKey: "YOUR_STREAMING_API_KEY"
    )
)
try streaming.register(provider: provider)
try streaming.connect()

// Subscribe to live balance updates:
let cancellable = streaming
    .balance(network: .mainnet, address: wallet.address.value)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion { print("stream error:", error) }
        },
        receiveValue: { update in
            print("New balance:", update.balance)
        }
    )
```

`streaming` also offers `.jettons(network:address:)`, `.transactions(network:address:)`,
`.updates(network:address:types:)`, and `.connectionChange(network:)`. Updates are emitted on
**change** — seed your UI with the current `wallet.balance()` first, then let the stream keep it
fresh. `TONTonApiStreamingProviderConfig` is available as an alternative provider.

## DeFi: swap, staking, gasless

Each DeFi area is a manager you obtain from the kit, after registering the relevant provider:

```swift
// Swap
let swap = try await kit.swap()
let omniston = try await kit.omnistonSwapProvider(config: nil)
try swap.register(provider: omniston)
// let dedust = try await kit.dedustSwapProvider(config: nil)
// quote / build a swap transaction via `swap.quote(…)` and `swap.swapTransaction(params:)`

// Staking
let staking = try await kit.staking()
let stakers = try await kit.stakingProvider(config: TONTonStakersProviderConfig(/* … */))
try staking.register(provider: stakers)

// Gasless (pay fees in jettons)
let gasless = try await kit.gasless()
let gaslessProvider = try await kit.tonApiGaslessProvider(config: TONTonApiGaslessProviderConfig(/* … */))
try gasless.register(provider: gaslessProvider)

// Jettons metadata/utilities
let jettons = try await kit.jettons()
```

## Working with amounts & addresses

- **`TONTokenAmount` / `TONBalance`** store value in nano-units (1 TON = 10⁹ nanoTON):

  ```swift
  let oneTon = TONTokenAmount(nanoUnits: "1000000000")!
  let display = TONBalanceFormatter().string(from: oneTon)   // "1"
  let parsed  = TONBalanceFormatter().amount(from: "1.5")     // TONTokenAmount?
  ```

- **`TONUserFriendlyAddress`** validates on init and exposes `.value`:

  ```swift
  let address = try TONUserFriendlyAddress(value: "EQ…")
  ```

- **`TONNetwork`** provides `.mainnet` and `.testnet`, or `TONNetwork(chainId:)` for custom chains.

## Error handling

Every failure is a strongly-typed Swift error — the SDK never throws bare strings. The user-facing
ones conform to `LocalizedError`, so `error.localizedDescription` is presentable:

```swift
do {
    let wallet = try await kit.wallet(id: walletID)
    _ = try await wallet.balance()
} catch let error as TONWalletKitError {
    // .notInitialized, .bridgeUnavailable, .streamingNetworkUnavailable, .bridgeRequestTimeout
    print("WalletKit error:", error.localizedDescription)
} catch {
    print("Unexpected:", error.localizedDescription)
}
```

Notable error types:

| Type | Raised when |
|---|---|
| `TONWalletKitError` | SDK lifecycle / bridge / streaming failures |
| `TONBase64ValidationError`, `TONHexValidationError` | invalid base64 / hex inputs |
| `JSValueConversionError` | a value can't be bridged to/from the JS core |
| `JSError` | an error surfaced from the embedded JS core |

## Development

The Swift API wraps a prebuilt JavaScript bundle (`Resources/JS/walletkit-ios-bridge.mjs`). You only
need this if you are developing the package itself and want to rebuild that bundle:

```bash
make js                              # build from the pinned walletkit source
make js WALLETKIT_PATH=<local_path>  # build from a local checkout
```

Run the test suite with the Xcode toolchain (which ships Swift Testing):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```
