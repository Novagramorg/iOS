/**
 * TONCrypto vectors: mnemonics, TON Proof, signData hashes, walletId, signatures.
 *
 * The two byte layouts in here are the highest-risk part of the whole port:
 * tonProof uses little-endian for domainLen/timestamp, signData uses big-endian
 * for the same fields plus a *signed* int32 workchain. Both are covered.
 */

import nacl from 'tweetnacl';
import { Address, beginCell } from '@ton/core';
import { deriveEd25519Path, keyPairFromSeed, mnemonicToWalletKey, sha256_sync } from '@ton/crypto';
import { mnemonicToSeed as bip39MnemonicToSeed } from '@scure/bip39';

import { CreateTonProofMessageBytes } from '../../../../kit-main/packages/walletkit/src/utils/tonProof.ts';
import { createTextBinaryHash, createCellHash } from '../../../../kit-main/packages/walletkit/src/utils/signData/hash.ts';
import { createWalletId } from '../../../../kit-main/packages/walletkit/src/utils/walletId.ts';
import { DefaultSignature, FakeSignature } from '../../../../kit-main/packages/walletkit/src/utils/sign.ts';
import { buf as crc32Buf } from '../../../../kit-main/packages/walletkit/src/utils/signData/crc32.ts';
import { b64, hex, seed, write } from '../util.ts';

// Fixed mnemonics. Generation is random, so vectors cover derivation only;
// generation is verified on the Swift side as a round-trip property instead.
const TON_MNEMONICS = [
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art',
    'legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth title',
    'letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic avoid letter advice cage absurd amount doctor acoustic bless',
    'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote',
];

const BIP39_MNEMONICS = [
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    'legal winner thank year wave sausage worth useful legal winner thank yellow',
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent',
];

const TON_DERIVATION_PATH = [44, 607, 0];

/**
 * Replicates walletkit's `MnemonicToKeyPair` by calling the same underlying
 * primitives it delegates to.
 *
 * We cannot import `utils/mnemonic.mts` directly: it is a strict-ESM `.mts`
 * module, walletkit's `.ts` files transpile to CJS under tsx (no "type": "module"
 * in its package.json), and the `export *` barrel in `src/errors/index.ts` is not
 * statically detectable across that boundary. The wrapper adds only a word-count
 * check on top of these calls, so nothing observable in the vectors is lost.
 */
async function tonMnemonicToKeyPair(words: string[]) {
    return mnemonicToWalletKey(words);
}

async function bip39MnemonicToKeyPair(words: string[]) {
    const seedBytes = await bip39MnemonicToSeed(words.join(' '));
    const container = await deriveEd25519Path(Buffer.from(seedBytes), TON_DERIVATION_PATH);
    return keyPairFromSeed(container.subarray(0, 32));
}

async function mnemonicVectors() {
    const out: unknown[] = [];

    for (const mnemonic of TON_MNEMONICS) {
        const words = mnemonic.split(' ');
        const key = await tonMnemonicToKeyPair(words);
        out.push({
            scheme: 'ton',
            wordCount: words.length,
            mnemonic,
            publicKey: hex(key.publicKey),
            secretKey: hex(key.secretKey),
        });
    }

    for (const mnemonic of BIP39_MNEMONICS) {
        const words = mnemonic.split(' ');
        const key = await bip39MnemonicToKeyPair(words);
        out.push({
            scheme: 'bip39',
            wordCount: words.length,
            mnemonic,
            // BIP-39 path is [44, 607, 0] via SLIP-0010 ed25519 derivation.
            derivationPath: TON_DERIVATION_PATH,
            publicKey: hex(key.publicKey),
            secretKey: hex(key.secretKey),
        });
    }

    return out;
}

/** keyPairFromSeed for the deterministic seeds the other sections reference by index. */
function keypairVectors() {
    return Array.from({ length: 10 }, (_, i) => {
        const kp = keyPairFromSeed(seed(i));
        return {
            seedIndex: i,
            seed: hex(seed(i)),
            publicKey: hex(kp.publicKey),
            secretKey: hex(kp.secretKey),
        };
    });
}

async function tonProofVectors() {
    const cases = [
        {
            label: 'basic',
            workchain: 0,
            addressHash: '0x83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8',
            domain: { lengthBytes: 11, value: 'example.com' },
            payload: 'test-payload',
            timestamp: 1700000000,
        },
        {
            label: 'masterchain',
            workchain: -1,
            addressHash: '0x3333333333333333333333333333333333333333333333333333333333333333',
            domain: { lengthBytes: 9, value: 'ton.local' },
            payload: '',
            timestamp: 0,
        },
        {
            label: 'unicode-domain',
            workchain: 0,
            addressHash: '0x2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc',
            // lengthBytes must be the UTF-8 byte count, not the character count.
            domain: { lengthBytes: Buffer.from('пример.рф', 'utf8').length, value: 'пример.рф' },
            payload: 'ünïcödé-payload-🚀',
            timestamp: 1893456000,
        },
        {
            label: 'long-payload',
            workchain: 0,
            addressHash: '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            domain: { lengthBytes: 3, value: 'a.b' },
            payload: 'x'.repeat(512),
            timestamp: 2147483647,
        },
    ];

    const out = [];
    for (const c of cases) {
        const kp = keyPairFromSeed(seed(0));

        // What the Swift port must produce: spec-correct, signed int32 workchain.
        const specMessage = specTonProofMessage(c);

        let referenceMessage: Uint8Array | undefined;
        let referenceError: string | undefined;
        try {
            referenceMessage = await CreateTonProofMessageBytes({
                workchain: c.workchain,
                addressHash: c.addressHash as `0x${string}`,
                domain: c.domain,
                payload: c.payload,
                timestamp: c.timestamp,
                stateInit: '' as never,
            });
        } catch (error) {
            referenceError = error instanceof Error ? error.message : String(error);
        }

        // Cross-check: wherever the reference works, our spec implementation must
        // agree byte-for-byte. That is what justifies trusting the spec-derived
        // value for masterchain, where the reference cannot produce one at all.
        if (referenceMessage && hex(referenceMessage) !== hex(specMessage)) {
            throw new Error(
                `vectorgen: spec/reference tonProof mismatch for "${c.label}":\n` +
                    `  reference: ${hex(referenceMessage)}\n` +
                    `  spec:      ${hex(specMessage)}`,
            );
        }

        out.push({
            ...c,
            messageHash: hex(specMessage),
            signature: DefaultSignature(specMessage, new Uint8Array(kp.secretKey)),
            // Provenance, so a reader can tell verified-against-reference values from
            // spec-derived ones.
            derivedFrom: referenceMessage ? 'reference-and-spec-agree' : 'spec-only',
            // DELIBERATE DIVERGENCE (approved): tonProof.ts writes the workchain with
            // writeUInt32BE, so masterchain (-1) throws instead of encoding 0xffffffff.
            // The TON Connect spec says "workchain (32-bit signed, big-endian)" and the
            // documented backend verifier uses writeInt32BE — as does walletkit's own
            // signData/hash.ts. We follow the spec. For workchain 0 the encodings are
            // byte-identical, so nothing that works today changes.
            referenceThrows: referenceError !== undefined,
            referenceError,
        });
    }
    return out;
}

/**
 * The ton_proof message exactly as the TON Connect spec defines it.
 *
 *   message = "ton-proof-item-v2/"
 *          ++ workchain   (int32  big-endian, SIGNED)
 *          ++ addressHash (32 bytes)
 *          ++ domainLen   (uint32 little-endian)
 *          ++ domain      (utf8)
 *          ++ timestamp   (uint64 little-endian)
 *          ++ payload     (utf8)
 *   result  = sha256(0xffff ++ "ton-connect" ++ sha256(message))
 *
 * The mixed endianness is the spec's, not a transcription error: domainLen and
 * timestamp really are little-endian here, while signData uses big-endian for the
 * same conceptual fields.
 */
function specTonProofMessage(c: {
    workchain: number;
    addressHash: string;
    domain: { lengthBytes: number; value: string };
    payload: string;
    timestamp: number;
}): Uint8Array {
    const wc = Buffer.alloc(4);
    wc.writeInt32BE(c.workchain);

    const ts = Buffer.alloc(8);
    ts.writeBigUInt64LE(BigInt(c.timestamp));

    const dl = Buffer.alloc(4);
    dl.writeUInt32LE(c.domain.lengthBytes);

    const addressHash = Buffer.from(c.addressHash.replace(/^0x/, ''), 'hex');

    const inner = Buffer.concat([
        Buffer.from('ton-proof-item-v2/'),
        wc,
        addressHash,
        dl,
        Buffer.from(c.domain.value),
        ts,
        Buffer.from(c.payload),
    ]);

    const outer = Buffer.concat([
        Buffer.from([0xff, 0xff]),
        Buffer.from('ton-connect'),
        sha256_sync(inner),
    ]);

    return new Uint8Array(sha256_sync(outer));
}

function signDataVectors() {
    const addr = Address.parse('0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8');
    const mcAddr = Address.parse('-1:3333333333333333333333333333333333333333333333333333333333333333');

    const textBinary = [
        { label: 'text-ascii', type: 'text' as const, content: 'Hello, TON!', addr, domain: 'example.com', ts: 1700000000 },
        { label: 'text-empty', type: 'text' as const, content: '', addr, domain: 'a.io', ts: 0 },
        {
            label: 'text-unicode',
            type: 'text' as const,
            content: 'Привет, мир! 🌍 日本語',
            addr,
            domain: 'пример.рф',
            ts: 1893456000,
        },
        {
            label: 'text-masterchain-negative-wc',
            type: 'text' as const,
            content: 'masterchain',
            addr: mcAddr,
            domain: 'mc.ton',
            ts: 1700000000,
        },
        {
            label: 'binary-basic',
            type: 'binary' as const,
            content: Buffer.from([0x00, 0x01, 0xfe, 0xff]).toString('base64'),
            addr,
            domain: 'example.com',
            ts: 1700000000,
        },
        {
            label: 'binary-empty',
            type: 'binary' as const,
            content: '',
            addr,
            domain: 'example.com',
            ts: 1700000000,
        },
        {
            label: 'binary-1kb',
            type: 'binary' as const,
            content: Buffer.alloc(1024, 0xab).toString('base64'),
            addr,
            domain: 'example.com',
            ts: 1700000000,
        },
    ].map((c) => ({
        label: c.label,
        payloadType: c.type,
        content: c.content,
        address: c.addr.toRawString(),
        workchain: c.addr.workChain,
        domain: c.domain,
        timestamp: c.ts,
        hash: hex(
            createTextBinaryHash(
                { type: c.type, value: { content: c.content } } as never,
                c.addr,
                c.domain,
                c.ts,
            ),
        ),
    }));

    const cellCases = [
        {
            label: 'cell-simple',
            schema: 'test#_ value:uint32 = Test;',
            cell: beginCell().storeUint(42, 32).endCell(),
            addr,
            domain: 'example.com',
            ts: 1700000000,
        },
        {
            label: 'cell-empty-payload',
            schema: 'empty#_ = Empty;',
            cell: beginCell().endCell(),
            addr,
            domain: 'a.b.c',
            ts: 0,
        },
        {
            label: 'cell-nested-refs',
            schema: 'nested#_ a:^Cell b:^Cell = Nested;',
            cell: beginCell()
                .storeRef(beginCell().storeUint(1, 8).endCell())
                .storeRef(beginCell().storeUint(2, 8).endCell())
                .endCell(),
            addr,
            domain: 'deep.example.com',
            ts: 1893456000,
        },
        {
            label: 'cell-masterchain',
            schema: 'mc#_ x:uint8 = Mc;',
            cell: beginCell().storeUint(7, 8).endCell(),
            addr: mcAddr,
            domain: 'mc.ton',
            ts: 1700000000,
        },
    ].map((c) => ({
        label: c.label,
        schema: c.schema,
        schemaCrc32: crc32Buf(Buffer.from(c.schema, 'utf8'), undefined) >>> 0,
        payloadBoc: b64(c.cell.toBoc()),
        address: c.addr.toRawString(),
        domain: c.domain,
        // TEP-81: reversed labels joined by NUL, with a trailing NUL.
        tep81Domain: hex(Buffer.from(c.domain.split('.').reverse().join('\0') + '\0', 'utf8')),
        timestamp: c.ts,
        hash: hex(createCellHash({ schema: c.schema, content: b64(c.cell.toBoc()) } as never, c.addr, c.domain, c.ts)),
    }));

    return { textBinary, cell: cellCases };
}

function crc32Vectors() {
    const inputs = [
        '',
        'a',
        'abc',
        'message digest',
        'test#_ value:uint32 = Test;',
        '123456789',
        'Привет',
        'x'.repeat(1000),
    ];
    return inputs.map((s) => ({
        input: s,
        inputHex: hex(Buffer.from(s, 'utf8')),
        crc32: crc32Buf(Buffer.from(s, 'utf8'), undefined) >>> 0,
    }));
}

function walletIdVectors() {
    const networks = [
        { chainId: '-239' },
        { chainId: '-3' },
        { chainId: '662387' },
    ];
    // Computed rather than hand-written: hand-typed friendly forms are easy to get
    // wrong, and an address with a bad checksum makes for a misleading vector even
    // though createWalletId only hashes the string it is given.
    const addresses = [
        Address.parseRaw('0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8').toString({
            urlSafe: true,
            bounceable: true,
            testOnly: false,
        }),
        Address.parseRaw('0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8').toString({
            urlSafe: true,
            bounceable: false,
            testOnly: false,
        }),
        Address.parseRaw('0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc').toString({
            urlSafe: true,
            bounceable: true,
            testOnly: false,
        }),
    ];
    const out = [];
    for (const network of networks) {
        for (const address of addresses) {
            out.push({
                chainId: network.chainId,
                address,
                // sha256("<chainId>:<address>"), base64-encoded
                preimage: `${network.chainId}:${address}`,
                walletId: createWalletId(network, address),
            });
        }
    }
    return out;
}

function signatureVectors() {
    const messages = ['', 'hello', 'x'.repeat(256)];
    const out: unknown[] = [];
    for (let i = 0; i < 3; i++) {
        const kp = keyPairFromSeed(seed(i));
        for (const m of messages) {
            const data = Buffer.from(m, 'utf8');
            out.push({
                seedIndex: i,
                publicKey: hex(kp.publicKey),
                message: m,
                messageHex: hex(data),
                // Signed with the 64-byte expanded key.
                signature: DefaultSignature(data, new Uint8Array(kp.secretKey)),
                // Signed with the 32-byte seed — must expand internally to the same result.
                signatureFromSeed: DefaultSignature(data, new Uint8Array(seed(i))),
                fakeSignature: FakeSignature(data),
            });
        }
    }
    return out;
}

function sha256Vectors() {
    const inputs = ['', 'abc', 'x'.repeat(1000), 'Привет, мир!'];
    return inputs.map((s) => ({
        input: s,
        inputHex: hex(Buffer.from(s, 'utf8')),
        sha256: hex(sha256_sync(Buffer.from(s, 'utf8'))),
    }));
}

export async function dumpCrypto(): Promise<void> {
    write('mnemonic.json', await mnemonicVectors());
    write('keypairs.json', keypairVectors());
    write('tonproof.json', await tonProofVectors());
    write('signdata.json', signDataVectors());
    write('crc32.json', crc32Vectors());
    write('walletid.json', walletIdVectors());
    write('signatures.json', signatureVectors());
    write('sha256.json', sha256Vectors());
    write('nacl-box.json', naclBoxVectors());
    write('x25519.json', x25519Vectors());
}

// ── NaCl box (TON Connect SessionCrypto) ─────────────────────────────────────

/**
 * X25519 + XSalsa20-Poly1305, generated with tweetnacl directly — the same library
 * `@tonconnect/protocol`'s SessionCrypto uses.
 *
 * Neither CryptoKit nor BoringSSL provides XSalsa20, so this is the one primitive with
 * no platform implementation available. Keys and nonces are fixed for determinism.
 */
function naclBoxVectors() {
    const out: unknown[] = [];

    const secretA = Buffer.alloc(32, 0xa1);
    const secretB = Buffer.alloc(32, 0xb2);
    const publicA = nacl.scalarMult.base(new Uint8Array(secretA));
    const publicB = nacl.scalarMult.base(new Uint8Array(secretB));

    const messages: [string, Buffer][] = [
        ['empty', Buffer.alloc(0)],
        ['short', Buffer.from('hello', 'utf8')],
        ['json-request', Buffer.from(JSON.stringify({ method: 'sendTransaction', id: '1' }), 'utf8')],
        ['binary', Buffer.from([0x00, 0xff, 0x7f, 0x80])],
        ['1kb', Buffer.alloc(1024, 0x5a)],
        ['unicode', Buffer.from('Привет 🌍', 'utf8')],
    ];

    for (const [label, message] of messages) {
        for (const [nonceLabel, nonce] of [
            ['zero-nonce', Buffer.alloc(24, 0)],
            ['patterned-nonce', Buffer.from(Array.from({ length: 24 }, (_, i) => i))],
        ] as [string, Buffer][]) {
            const box = nacl.box(
                new Uint8Array(message),
                new Uint8Array(nonce),
                publicB,
                new Uint8Array(secretA),
            );
            out.push({
                label: `${label}/${nonceLabel}`,
                secretA: hex(secretA),
                publicA: hex(Buffer.from(publicA)),
                secretB: hex(secretB),
                publicB: hex(Buffer.from(publicB)),
                nonce: hex(nonce),
                message: hex(message),
                // Compact form: message length plus a 16-byte authenticator.
                box: hex(Buffer.from(box)),
            });
        }
    }

    return out;
}

/** X25519 public-key derivation, so the key-agreement half is covered separately. */
function x25519Vectors() {
    return [0xa1, 0xb2, 0x00, 0xff, 0x01].map((fill) => {
        const secret = Buffer.alloc(32, fill);
        return {
            secretKey: hex(secret),
            publicKey: hex(Buffer.from(nacl.scalarMult.base(new Uint8Array(secret)))),
        };
    });
}
