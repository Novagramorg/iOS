/*
 * Implementation of the explicit C API declared in tweetnacl_shim.h.
 *
 * tweetnacl.c is #included rather than compiled separately because
 * ton_ed25519_seed_keypair needs its file-local `scalarbase` and `pack`. The vendored
 * source is excluded from the target's own source list (see Package.swift) so it is
 * compiled exactly once, here, and stays byte-identical to upstream.
 */
#include "tweetnacl.c"
#include "include/tweetnacl_shim.h"

#include <stdlib.h>
#include <string.h>

#define TON_SIG_BYTES 64
#define TON_BOX_ZEROBYTES 32
#define TON_BOX_BOXZEROBYTES 16

int ton_ed25519_seed_keypair(
    unsigned char *pk,
    unsigned char *sk,
    const unsigned char *seed
) {
    unsigned char d[64];
    gf p[4];
    int i;

    /* Mirrors crypto_sign_keypair with randombytes() replaced by the given seed. */
    for (i = 0; i < 32; ++i) sk[i] = seed[i];

    crypto_hash(d, sk, 32);
    d[0] &= 248;
    d[31] &= 127;
    d[31] |= 64;

    scalarbase(p, d);
    pack(pk, p);

    for (i = 0; i < 32; ++i) sk[32 + i] = pk[i];

    return 0;
}

int ton_ed25519_sign_detached(
    unsigned char *sig,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *sk
) {
    /* crypto_sign emits signature ‖ message, so it needs a full-length buffer. */
    unsigned long long signed_len = message_len + TON_SIG_BYTES;
    unsigned char *signed_message = malloc((size_t)signed_len);
    if (!signed_message) return -1;

    unsigned long long produced = 0;
    int status = crypto_sign(signed_message, &produced, message, message_len, sk);
    if (status == 0) memcpy(sig, signed_message, TON_SIG_BYTES);

    free(signed_message);
    return status;
}

int ton_ed25519_verify_detached(
    const unsigned char *sig,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *pk
) {
    unsigned long long signed_len = message_len + TON_SIG_BYTES;
    unsigned char *signed_message = malloc((size_t)signed_len);
    unsigned char *recovered = malloc((size_t)signed_len);
    if (!signed_message || !recovered) {
        free(signed_message);
        free(recovered);
        return -1;
    }

    memcpy(signed_message, sig, TON_SIG_BYTES);
    if (message_len > 0) memcpy(signed_message + TON_SIG_BYTES, message, (size_t)message_len);

    unsigned long long produced = 0;
    int status = crypto_sign_open(recovered, &produced, signed_message, signed_len, pk);

    free(signed_message);
    free(recovered);
    return status;
}

int ton_x25519_keypair(unsigned char *pk, unsigned char *sk) {
    return crypto_box_keypair(pk, sk);
}

int ton_x25519_public_from_secret(unsigned char *pk, const unsigned char *sk) {
    return crypto_scalarmult_base(pk, sk);
}

int ton_box_seal(
    unsigned char *box,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *nonce,
    const unsigned char *their_pk,
    const unsigned char *my_sk
) {
    /* NaCl requires ZEROBYTES of leading zeros on the plaintext. */
    unsigned long long padded_len = message_len + TON_BOX_ZEROBYTES;
    unsigned char *padded = calloc((size_t)padded_len, 1);
    unsigned char *ciphertext = calloc((size_t)padded_len, 1);
    if (!padded || !ciphertext) {
        free(padded);
        free(ciphertext);
        return -1;
    }

    if (message_len > 0) {
        memcpy(padded + TON_BOX_ZEROBYTES, message, (size_t)message_len);
    }

    int status = crypto_box(ciphertext, padded, padded_len, nonce, their_pk, my_sk);
    if (status == 0) {
        /* Drop the BOXZEROBYTES prefix to yield the compact form. */
        memcpy(box, ciphertext + TON_BOX_BOXZEROBYTES, (size_t)(padded_len - TON_BOX_BOXZEROBYTES));
    }

    free(padded);
    free(ciphertext);
    return status;
}

int ton_box_open(
    unsigned char *message,
    const unsigned char *box,
    unsigned long long box_len,
    const unsigned char *nonce,
    const unsigned char *their_pk,
    const unsigned char *my_sk
) {
    unsigned long long padded_len = box_len + TON_BOX_BOXZEROBYTES;
    unsigned char *padded = calloc((size_t)padded_len, 1);
    unsigned char *plaintext = calloc((size_t)padded_len, 1);
    if (!padded || !plaintext) {
        free(padded);
        free(plaintext);
        return -1;
    }

    memcpy(padded + TON_BOX_BOXZEROBYTES, box, (size_t)box_len);

    int status = crypto_box_open(plaintext, padded, padded_len, nonce, their_pk, my_sk);
    if (status == 0 && padded_len > TON_BOX_ZEROBYTES) {
        memcpy(message, plaintext + TON_BOX_ZEROBYTES, (size_t)(padded_len - TON_BOX_ZEROBYTES));
    }

    free(padded);
    free(plaintext);
    return status;
}
