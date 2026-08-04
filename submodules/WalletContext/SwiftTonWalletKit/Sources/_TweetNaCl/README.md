# _TweetNaCl

Vendored TweetNaCl, version 20140427, retrieved from the authors' canonical
distribution at <https://tweetnacl.cr.yp.to/>.

**Public domain** (TweetNaCl is released into the public domain by its authors:
Bernstein, van Gastel, Janssen, Lange, Schwabe, Smetsers).

## Why this is here

The reference TypeScript implementation uses this exact library:

- `@ton/crypto` signs with `tweetnacl` (`nacl.sign.detached`)
- `@tonconnect/protocol`'s `SessionCrypto` boxes with `tweetnacl` (`nacl.box`)

Using the same implementation gives byte-for-byte parity with the golden vectors and
the same security provenance as the reference.

It is here rather than CryptoKit because **CryptoKit's Ed25519 signing is randomized** —
it does not implement RFC 8032 deterministic nonce derivation — and because CryptoKit
has no XSalsa20-Poly1305 at all, which TON Connect's session encryption requires.
BoringSSL would cover Ed25519 and X25519 but also lacks Salsa20.

## Modifications

`tweetnacl.c` and `tweetnacl.h` are byte-identical to upstream. Two files are ours:

- `randombytes.c` — TweetNaCl declares `randombytes` extern and leaves it to the
  integrator.
- `tweetnacl_shim.c` — adds `ton_crypto_sign_seed_keypair`. TweetNaCl only offers
  `crypto_sign_keypair`, which generates its own random seed, but `crypto_sign` needs
  the public key already present in `sk[32..64]`, so deriving a key pair from a
  caller-supplied seed requires `scalarbase` and `pack` — file-local statics. The shim
  `#include`s `tweetnacl.c` to bring them into scope, and `tweetnacl.c` is excluded from
  the target's source list so it compiles exactly once and stays pristine.

## Swapping this out

`TONCrypto` accesses this only through the `Ed25519Signing` and `KeyExchanging`
protocols, so a host application can inject its own implementation (for example a
BoringSSL-backed one) without changes here.
