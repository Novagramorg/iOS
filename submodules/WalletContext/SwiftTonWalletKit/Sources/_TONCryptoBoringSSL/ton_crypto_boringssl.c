#include "include/ton_crypto_boringssl.h"

#include <openssl/curve25519.h>
#include <openssl/mem.h>
#include <openssl/poly1305.h>

#include <limits.h>
#include <string.h>

static uint32_t ton_load32_le(const uint8_t value[4]) {
    return ((uint32_t)value[0])
        | ((uint32_t)value[1] << 8)
        | ((uint32_t)value[2] << 16)
        | ((uint32_t)value[3] << 24);
}

static void ton_store32_le(uint8_t output[4], uint32_t value) {
    output[0] = (uint8_t)value;
    output[1] = (uint8_t)(value >> 8);
    output[2] = (uint8_t)(value >> 16);
    output[3] = (uint8_t)(value >> 24);
}

static uint32_t ton_rotate_left(uint32_t value, unsigned int shift) {
    return (value << shift) | (value >> (32 - shift));
}

static void ton_salsa20_rounds(uint32_t x[16]) {
    int round;
    for (round = 0; round < 20; round += 2) {
        x[4] ^= ton_rotate_left(x[0] + x[12], 7);
        x[8] ^= ton_rotate_left(x[4] + x[0], 9);
        x[12] ^= ton_rotate_left(x[8] + x[4], 13);
        x[0] ^= ton_rotate_left(x[12] + x[8], 18);

        x[9] ^= ton_rotate_left(x[5] + x[1], 7);
        x[13] ^= ton_rotate_left(x[9] + x[5], 9);
        x[1] ^= ton_rotate_left(x[13] + x[9], 13);
        x[5] ^= ton_rotate_left(x[1] + x[13], 18);

        x[14] ^= ton_rotate_left(x[10] + x[6], 7);
        x[2] ^= ton_rotate_left(x[14] + x[10], 9);
        x[6] ^= ton_rotate_left(x[2] + x[14], 13);
        x[10] ^= ton_rotate_left(x[6] + x[2], 18);

        x[3] ^= ton_rotate_left(x[15] + x[11], 7);
        x[7] ^= ton_rotate_left(x[3] + x[15], 9);
        x[11] ^= ton_rotate_left(x[7] + x[3], 13);
        x[15] ^= ton_rotate_left(x[11] + x[7], 18);

        x[1] ^= ton_rotate_left(x[0] + x[3], 7);
        x[2] ^= ton_rotate_left(x[1] + x[0], 9);
        x[3] ^= ton_rotate_left(x[2] + x[1], 13);
        x[0] ^= ton_rotate_left(x[3] + x[2], 18);

        x[6] ^= ton_rotate_left(x[5] + x[4], 7);
        x[7] ^= ton_rotate_left(x[6] + x[5], 9);
        x[4] ^= ton_rotate_left(x[7] + x[6], 13);
        x[5] ^= ton_rotate_left(x[4] + x[7], 18);

        x[11] ^= ton_rotate_left(x[10] + x[9], 7);
        x[8] ^= ton_rotate_left(x[11] + x[10], 9);
        x[9] ^= ton_rotate_left(x[8] + x[11], 13);
        x[10] ^= ton_rotate_left(x[9] + x[8], 18);

        x[12] ^= ton_rotate_left(x[15] + x[14], 7);
        x[13] ^= ton_rotate_left(x[12] + x[15], 9);
        x[14] ^= ton_rotate_left(x[13] + x[12], 13);
        x[15] ^= ton_rotate_left(x[14] + x[13], 18);
    }
}

static void ton_salsa20_state(uint32_t state[16], const uint8_t input[16], const uint8_t key[32]) {
    static const uint8_t sigma[16] = "expand 32-byte k";

    state[0] = ton_load32_le(sigma + 0);
    state[5] = ton_load32_le(sigma + 4);
    state[10] = ton_load32_le(sigma + 8);
    state[15] = ton_load32_le(sigma + 12);
    state[1] = ton_load32_le(key + 0);
    state[2] = ton_load32_le(key + 4);
    state[3] = ton_load32_le(key + 8);
    state[4] = ton_load32_le(key + 12);
    state[11] = ton_load32_le(key + 16);
    state[12] = ton_load32_le(key + 20);
    state[13] = ton_load32_le(key + 24);
    state[14] = ton_load32_le(key + 28);
    state[6] = ton_load32_le(input + 0);
    state[7] = ton_load32_le(input + 4);
    state[8] = ton_load32_le(input + 8);
    state[9] = ton_load32_le(input + 12);
}

static void ton_hsalsa20(uint8_t output[32], const uint8_t input[16], const uint8_t key[32]) {
    uint32_t state[16];
    ton_salsa20_state(state, input, key);
    ton_salsa20_rounds(state);

    ton_store32_le(output + 0, state[0]);
    ton_store32_le(output + 4, state[5]);
    ton_store32_le(output + 8, state[10]);
    ton_store32_le(output + 12, state[15]);
    ton_store32_le(output + 16, state[6]);
    ton_store32_le(output + 20, state[7]);
    ton_store32_le(output + 24, state[8]);
    ton_store32_le(output + 28, state[9]);
    OPENSSL_cleanse(state, sizeof(state));
}

static void ton_salsa20_block(uint8_t output[64], const uint8_t nonce[8], uint64_t counter, const uint8_t key[32]) {
    uint8_t input[16];
    uint32_t initial[16];
    uint32_t state[16];
    size_t index;

    memcpy(input, nonce, 8);
    for (index = 0; index < 8; ++index) {
        input[8 + index] = (uint8_t)(counter >> (index * 8));
    }
    ton_salsa20_state(initial, input, key);
    memcpy(state, initial, sizeof(state));
    ton_salsa20_rounds(state);
    for (index = 0; index < 16; ++index) {
        ton_store32_le(output + index * 4, state[index] + initial[index]);
    }

    OPENSSL_cleanse(input, sizeof(input));
    OPENSSL_cleanse(initial, sizeof(initial));
    OPENSSL_cleanse(state, sizeof(state));
}

static int ton_xsalsa20_xor_after_poly_key(
    uint8_t *output,
    const uint8_t *input,
    size_t length,
    const uint8_t nonce[24],
    const uint8_t key[32],
    uint8_t poly_key[32]
) {
    uint8_t subkey[32];
    uint8_t block[64];
    size_t offset = 0;
    size_t index;
    uint64_t counter = 0;

    ton_hsalsa20(subkey, nonce, key);
    ton_salsa20_block(block, nonce + 16, counter, subkey);
    memcpy(poly_key, block, 32);

    while (offset < length && offset < 32) {
        output[offset] = input[offset] ^ block[32 + offset];
        ++offset;
    }
    counter = 1;
    while (offset < length) {
        size_t count = length - offset;
        if (count > sizeof(block)) {
            count = sizeof(block);
        }
        ton_salsa20_block(block, nonce + 16, counter, subkey);
        for (index = 0; index < count; ++index) {
            output[offset + index] = input[offset + index] ^ block[index];
        }
        offset += count;
        if (counter == UINT64_MAX && offset < length) {
            OPENSSL_cleanse(subkey, sizeof(subkey));
            OPENSSL_cleanse(block, sizeof(block));
            OPENSSL_cleanse(poly_key, 32);
            return 0;
        }
        ++counter;
    }

    OPENSSL_cleanse(subkey, sizeof(subkey));
    OPENSSL_cleanse(block, sizeof(block));
    return 1;
}

static int ton_box_key(
    uint8_t output[32],
    const uint8_t peer_public_key[32],
    const uint8_t private_key[32]
) {
    static const uint8_t zero[16] = {0};
    uint8_t shared[32];
    if (!X25519(shared, private_key, peer_public_key)) {
        OPENSSL_cleanse(shared, sizeof(shared));
        return 0;
    }
    ton_hsalsa20(output, zero, shared);
    OPENSSL_cleanse(shared, sizeof(shared));
    return 1;
}

int ton_bssl_ed25519_keypair_from_seed(
    uint8_t public_key[32],
    uint8_t secret_key[64],
    const uint8_t seed[32]
) {
    ED25519_keypair_from_seed(public_key, secret_key, seed);
    return 1;
}

int ton_bssl_ed25519_sign(
    uint8_t signature[64],
    const uint8_t *message,
    size_t message_length,
    const uint8_t secret_key[64]
) {
    return ED25519_sign(signature, message, message_length, secret_key);
}

int ton_bssl_ed25519_verify(
    const uint8_t signature[64],
    const uint8_t *message,
    size_t message_length,
    const uint8_t public_key[32]
) {
    return ED25519_verify(message, message_length, signature, public_key);
}

int ton_bssl_x25519_keypair(uint8_t public_key[32], uint8_t secret_key[32]) {
    X25519_keypair(public_key, secret_key);
    return 1;
}

int ton_bssl_x25519_public_from_private(uint8_t public_key[32], const uint8_t secret_key[32]) {
    X25519_public_from_private(public_key, secret_key);
    return 1;
}

int ton_bssl_box_seal(
    uint8_t *box,
    const uint8_t *message,
    size_t message_length,
    const uint8_t nonce[24],
    const uint8_t peer_public_key[32],
    const uint8_t private_key[32]
) {
    uint8_t key[32] = {0};
    uint8_t poly_key[32] = {0};
    poly1305_state poly1305 = {0};
    int result = 0;

    if (!ton_box_key(key, peer_public_key, private_key)) {
        goto cleanup;
    }
    if (!ton_xsalsa20_xor_after_poly_key(box + 16, message, message_length, nonce, key, poly_key)) {
        goto cleanup;
    }
    CRYPTO_poly1305_init(&poly1305, poly_key);
    CRYPTO_poly1305_update(&poly1305, box + 16, message_length);
    CRYPTO_poly1305_finish(&poly1305, box);
    result = 1;

cleanup:
    OPENSSL_cleanse(key, sizeof(key));
    OPENSSL_cleanse(poly_key, sizeof(poly_key));
    OPENSSL_cleanse(&poly1305, sizeof(poly1305));
    return result;
}

int ton_bssl_box_open(
    uint8_t *message,
    const uint8_t *box,
    size_t box_length,
    const uint8_t nonce[24],
    const uint8_t peer_public_key[32],
    const uint8_t private_key[32]
) {
    uint8_t key[32] = {0};
    uint8_t poly_key[32] = {0};
    uint8_t expected_tag[16] = {0};
    uint8_t ignored_stream[1] = {0};
    poly1305_state poly1305 = {0};
    size_t message_length;
    int result = 0;

    if (box_length < 16) {
        return 0;
    }
    message_length = box_length - 16;
    if (!ton_box_key(key, peer_public_key, private_key)) {
        goto cleanup;
    }

    /* Produce only the one-time Poly1305 key before authenticating. */
    if (!ton_xsalsa20_xor_after_poly_key(ignored_stream, ignored_stream, 0, nonce, key, poly_key)) {
        goto cleanup;
    }
    CRYPTO_poly1305_init(&poly1305, poly_key);
    CRYPTO_poly1305_update(&poly1305, box + 16, message_length);
    CRYPTO_poly1305_finish(&poly1305, expected_tag);
    if (CRYPTO_memcmp(expected_tag, box, sizeof(expected_tag)) != 0) {
        goto cleanup;
    }

    if (!ton_xsalsa20_xor_after_poly_key(message, box + 16, message_length, nonce, key, poly_key)) {
        goto cleanup;
    }
    result = 1;

cleanup:
    OPENSSL_cleanse(key, sizeof(key));
    OPENSSL_cleanse(poly_key, sizeof(poly_key));
    OPENSSL_cleanse(expected_tag, sizeof(expected_tag));
    OPENSSL_cleanse(ignored_stream, sizeof(ignored_stream));
    OPENSSL_cleanse(&poly1305, sizeof(poly1305));
    return result;
}
