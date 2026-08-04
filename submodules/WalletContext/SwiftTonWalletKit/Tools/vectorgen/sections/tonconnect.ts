/**
 * TON Connect SessionCrypto vectors, generated with @tonconnect/protocol itself.
 *
 * The envelope is unobvious: `encrypt` returns `nonce ‖ box`, with the 24-byte nonce
 * prepended rather than carried separately. Getting that wrong yields ciphertexts no
 * dApp can open.
 *
 * Encryption uses a random nonce, so the recorded ciphertexts cannot be reproduced
 * byte-for-byte. They are still exact test data for **decryption**, which is the harder
 * direction and the one a wallet does on every inbound bridge message.
 */

import { SessionCrypto } from '@tonconnect/protocol';
import nacl from 'tweetnacl';

import { hex, write } from '../util.ts';

function sessionCryptoVectors() {
    const out: unknown[] = [];

    // Fixed keypairs so sessionIds and public keys are stable across runs.
    const walletSecret = Buffer.alloc(32, 0x11);
    const appSecret = Buffer.alloc(32, 0x22);
    const walletPublic = Buffer.from(nacl.scalarMult.base(new Uint8Array(walletSecret)));
    const appPublic = Buffer.from(nacl.scalarMult.base(new Uint8Array(appSecret)));

    const wallet = new SessionCrypto({
        publicKey: hex(walletPublic),
        secretKey: hex(walletSecret),
    });
    const app = new SessionCrypto({
        publicKey: hex(appPublic),
        secretKey: hex(appSecret),
    });

    const messages = [
        '{"id":"1","method":"sendTransaction","params":["{}"]}',
        '',
        'plain text',
        JSON.stringify({ event: 'connect', payload: { items: [], device: {} } }),
        'unicode ✅ Привет 🌍',
        'x'.repeat(2048),
    ];

    for (const message of messages) {
        // App -> wallet, which is the direction a wallet must decrypt.
        const encrypted = app.encrypt(message, new Uint8Array(walletPublic));
        out.push({
            label: message.length > 24 ? `${message.slice(0, 24)}…` : (message || '<empty>'),
            plaintext: message,
            senderPublicKey: hex(appPublic),
            senderSecretKey: hex(appSecret),
            receiverPublicKey: hex(walletPublic),
            receiverSecretKey: hex(walletSecret),
            // nonce ‖ box, base64. The first 24 bytes are the nonce.
            envelope: Buffer.from(encrypted).toString('base64'),
            nonceLength: 24,
            // Round-trip through the reference, as a sanity check on the fixture itself.
            roundTripped: wallet.decrypt(encrypted, new Uint8Array(appPublic)) === message,
        });
    }

    return out;
}

/** `sessionId` is the hex-encoded X25519 public key. */
function sessionIdVectors() {
    return [0x11, 0x22, 0x00, 0xff].map((fill) => {
        const secret = Buffer.alloc(32, fill);
        const publicKey = Buffer.from(nacl.scalarMult.base(new Uint8Array(secret)));
        const crypto = new SessionCrypto({ publicKey: hex(publicKey), secretKey: hex(secret) });
        return {
            secretKey: hex(secret),
            publicKey: hex(publicKey),
            sessionId: crypto.sessionId,
        };
    });
}

export function dumpTonConnect(): void {
    write('sessioncrypto.json', sessionCryptoVectors());
    write('sessionid.json', sessionIdVectors());
}
