#ifndef TON_TWEETNACL_SHIM_H
#define TON_TWEETNACL_SHIM_H

/*
 * Explicit C API over TweetNaCl for the Swift side.
 *
 * TweetNaCl's friendly names (crypto_sign, crypto_box, …) are preprocessor macros
 * expanding to suffixed symbols such as crypto_sign_ed25519_tweet. Macros are not
 * imported into Swift as functions, so calling them from Swift would mean hard-coding
 * the suffixed spellings and coupling to an implementation detail. These wrappers give
 * stable names instead, and fold in the NaCl zero-padding conventions.
 *
 * All functions return 0 on success. Box-open returns non-zero when authentication
 * fails, which callers must treat as an ordinary outcome.
 */

/* --- ed25519 ------------------------------------------------------------- */

/*
 * Derives a key pair from a 32-byte seed: `pk` gets 32 bytes, `sk` gets 64
 * (seed followed by public key, the NaCl layout).
 *
 * TweetNaCl only exposes crypto_sign_keypair, which generates its own random seed,
 * so this is implemented against its file-local internals.
 */
int ton_ed25519_seed_keypair(
    unsigned char *pk,
    unsigned char *sk,
    const unsigned char *seed
);

/* Writes a detached 64-byte signature to `sig`. `sk` is the 64-byte secret key. */
int ton_ed25519_sign_detached(
    unsigned char *sig,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *sk
);

/* Returns 0 when the detached signature is valid. */
int ton_ed25519_verify_detached(
    const unsigned char *sig,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *pk
);

/* --- X25519 and crypto_box ------------------------------------------------ */

int ton_x25519_keypair(unsigned char *pk, unsigned char *sk);

int ton_x25519_public_from_secret(unsigned char *pk, const unsigned char *sk);

/*
 * Seals `message` (length `message_len`) into `box`, which must have room for
 * message_len + 16 bytes. Padding conventions are handled internally, so `box`
 * receives the compact form that tweetnacl-js produces.
 */
int ton_box_seal(
    unsigned char *box,
    const unsigned char *message,
    unsigned long long message_len,
    const unsigned char *nonce,
    const unsigned char *their_pk,
    const unsigned char *my_sk
);

/*
 * Opens a compact-form box. `message` must have room for box_len - 16 bytes.
 * Returns non-zero when authentication fails.
 */
int ton_box_open(
    unsigned char *message,
    const unsigned char *box,
    unsigned long long box_len,
    const unsigned char *nonce,
    const unsigned char *their_pk,
    const unsigned char *my_sk
);

#endif
