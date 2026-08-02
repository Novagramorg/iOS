#ifndef TON_CRYPTO_BORINGSSL_H
#define TON_CRYPTO_BORINGSSL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int ton_bssl_ed25519_keypair_from_seed(
    uint8_t public_key[32],
    uint8_t secret_key[64],
    const uint8_t seed[32]
);

int ton_bssl_ed25519_sign(
    uint8_t signature[64],
    const uint8_t *message,
    size_t message_length,
    const uint8_t secret_key[64]
);

int ton_bssl_ed25519_verify(
    const uint8_t signature[64],
    const uint8_t *message,
    size_t message_length,
    const uint8_t public_key[32]
);

int ton_bssl_x25519_keypair(uint8_t public_key[32], uint8_t secret_key[32]);
int ton_bssl_x25519_public_from_private(uint8_t public_key[32], const uint8_t secret_key[32]);

/*
 * NaCl crypto_box compact format: Poly1305 tag followed by ciphertext.
 * The caller provides output_length == message_length + 16 for seal and
 * message_length == box_length - 16 for open.
 */
int ton_bssl_box_seal(
    uint8_t *box,
    const uint8_t *message,
    size_t message_length,
    const uint8_t nonce[24],
    const uint8_t peer_public_key[32],
    const uint8_t private_key[32]
);

int ton_bssl_box_open(
    uint8_t *message,
    const uint8_t *box,
    size_t box_length,
    const uint8_t nonce[24],
    const uint8_t peer_public_key[32],
    const uint8_t private_key[32]
);

#ifdef __cplusplus
}
#endif

#endif
