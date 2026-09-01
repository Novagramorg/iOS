#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const WalletBackupCryptoErrorDomain;

typedef NS_ERROR_ENUM(WalletBackupCryptoErrorDomain, WalletBackupCryptoErrorCode) {
    WalletBackupCryptoErrorInvalidInput = 1,
    WalletBackupCryptoErrorKeyGeneration = 2,
    WalletBackupCryptoErrorKeyAgreement = 3,
    WalletBackupCryptoErrorEncryption = 4,
    WalletBackupCryptoErrorDecryption = 5,
    WalletBackupCryptoErrorInvalidPayload = 6,
};

/// Owns one in-memory ephemeral Ed25519 key from the calls e2e library.
/// The corresponding private key never crosses the Objective-C boundary.
@interface WalletBackupCryptoKeyPair : NSObject

@property (nonatomic, readonly) NSData *publicKey;

+ (nullable instancetype)generate:(NSError * _Nullable * _Nullable)error;
+ (nullable instancetype)generateKeyPair NS_SWIFT_NAME(generateKeyPair());

/// Decrypts exactly three bare or observed-wrapper envelopes, parses
/// mnemonic.decryptedKeyPart and XORs their shares.
- (nullable NSData *)decryptAndCombineEnvelopes:(NSArray<NSData *> *)envelopes
                                          error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)decryptAndCombineBackupEnvelopes:(NSArray<NSData *> *)envelopes
    NS_SWIFT_NAME(decryptAndCombineBackupEnvelopes(_:));

@end

@interface WalletBackupCrypto : NSObject

/// Splits `secret` into three XOR shares and encrypts them in holder order.
/// A distinct ephemeral key is used for each holder.
+ (nullable NSArray<NSData *> *)encryptSecret:(NSData *)secret
                          holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys
                                     error:(NSError * _Nullable * _Nullable)error;
/// Encrypts the shares as bare `ephemeralPublicKey || ciphertext` envelopes
/// for wallet.enableBackup.
+ (nullable NSArray<NSData *> *)encryptSecretForBackup:(NSData *)secret
                                      holderPublicKeys:(NSArray<NSData *> *)holderPublicKeys
    NS_SWIFT_NAME(encryptSecretForBackup(_:holderPublicKeys:));

@end

NS_ASSUME_NONNULL_END
