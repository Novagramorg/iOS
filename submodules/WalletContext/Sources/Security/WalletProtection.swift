import Foundation
import LocalAuthentication
import PasscodeCore

public let walletBiometricKeychainService = "org.telegram.ton-wallet.vault.v1.biometric"

public struct WalletProtectionSettings: Equatable, Sendable {
    public let passcode: PasscodeCredentialReference?
    public let enabled: Bool
    public let biometricsEnabled: Bool
}

public func walletProtectionSettings(credentials: PasscodeCredentialStore = .shared) throws -> WalletProtectionSettings {
    let settings = try credentials.protectionSettings()
    return WalletProtectionSettings(passcode: settings.passcode, enabled: settings.enabled, biometricsEnabled: settings.biometricsEnabled)
}

public func setWalletProtectionEnabled(_ enabled: Bool, session: PasscodeSession, credentials: PasscodeCredentialStore = .shared) throws {
    try setWalletProtectionEnabled(enabled, session: session, credentials: credentials, migrateWallets: WalletVault.migrateAll)
}

func setWalletProtectionEnabled(_ enabled: Bool, session: PasscodeSession, credentials: PasscodeCredentialStore, migrateWallets: () throws -> Void) throws {
    try credentials.validate(session, scope: .settings)
    guard try credentials.protectionSettings().enabled != enabled else {
        return
    }
    if enabled {
        try migrateWallets()
        try credentials.resumeCleanup()
    }
    try credentials.setProtectionEnabled(enabled, session: session)
}

public func setWalletBiometricsEnabled(_ enabled: Bool, session: PasscodeSession, context: LAContext, credentials: PasscodeCredentialStore = .shared) throws {
    try credentials.validate(session, scope: .settings)
    let settings = try credentials.protectionSettings()
    guard settings.enabled else {
        throw PasscodeError.authenticationRequired
    }
    guard settings.biometricsEnabled != enabled else {
        return
    }
    if enabled {
        try credentials.enableBiometrics(session: session, context: context)
    } else {
        try credentials.disableBiometrics(session: session)
    }
}

public func authenticateWalletBiometrics(namespace: String, lifetime: PasscodeSession.Lifetime = .standard, context: LAContext, credentials: PasscodeCredentialStore = .shared) throws -> PasscodeSession {
    return try credentials.authenticateBiometrics(context: context, scope: .resource(namespace: namespace), lifetime: lifetime)
}

public func resetWalletLocalSecrets(environment: PasscodeEnvironment = .shared, credentials: PasscodeCredentialStore = .shared) throws {
    try resetWalletLocalSecrets(environment: environment, credentials: credentials) {
        try WalletVault.removeAll(environment: environment)
    }
}

func resetWalletLocalSecrets(environment: PasscodeEnvironment, credentials: PasscodeCredentialStore, removingWalletData: () throws -> Void) throws {
    guard environment.isMainApp else { throw PasscodeError.unavailable }
    try credentials.resetCredential(removingProtectedData: removingWalletData)
}

public func _internalResetLocalSecretsForPasscodeMigrationTest(then: () throws -> Never) throws -> Never {
    let environment = PasscodeEnvironment.shared
    guard environment.isMainApp else { throw PasscodeError.unavailable }
    try PasscodeCredentialStore.shared._internalResetForPasscodeMigrationTest(removingProtectedData: {
        try WalletVault.removeAll(environment: environment)
    }, then: then)
}
