/**
 * TONCore vectors: BoC, Address, Dictionary, TL-B messages, TVM tuples.
 */

import {
    Address,
    beginCell,
    Cell,
    Dictionary,
    external,
    internal,
    loadMessage,
    loadMessageRelaxed,
    storeMessage,
    storeMessageRelaxed,
    type MessageRelaxed,
} from '@ton/core';

import { ParseStack, type RawStackItem } from '../../../../kit-main/packages/walletkit/src/utils/tvmStack.ts';
import { WalletV5R1CodeCell } from '../../../../kit-main/packages/walletkit/src/contracts/w5/WalletV5R1.source.ts';
import { WalletV4R2CodeCell } from '../../../../kit-main/packages/walletkit/src/contracts/v4r2/WalletV4R2.source.ts';
import { b64, expectThrow, hex, write } from '../util.ts';

// ── BoC ──────────────────────────────────────────────────────────────────────

function describeCell(label: string, cell: Cell) {
    return {
        label,
        // Three encodings, because the flags change the header layout and the
        // Swift deserializer must handle all of them.
        boc: b64(cell.toBoc()),
        bocPlain: b64(cell.toBoc({ idx: false, crc32: false })),
        bocIdxCrc32: b64(cell.toBoc({ idx: true, crc32: true })),
        hash: hex(cell.hash()),
        depth: cell.depth(),
        level: cell.level(),
        isExotic: cell.isExotic,
        bitsLength: cell.bits.length,
        bitsHex: cell.bits.toString(),
        refCount: cell.refs.length,
    };
}

function bocVectors() {
    const cells: [string, Cell][] = [];

    cells.push(['empty', beginCell().endCell()]);
    cells.push(['single-bit-1', beginCell().storeBit(true).endCell()]);
    cells.push(['single-bit-0', beginCell().storeBit(false).endCell()]);
    cells.push(['byte-0xff', beginCell().storeUint(0xff, 8).endCell()]);

    // Maximum payload: 1023 bits. Exercises the augmented-bits tail encoding.
    const max = beginCell();
    for (let i = 0; i < 127; i++) max.storeUint(i & 0xff, 8);
    max.storeUint(0b1111111, 7);
    cells.push(['max-1023-bits', max.endCell()]);

    cells.push(['bits-1022', beginCell().storeUint(0, 1022).endCell()]);
    cells.push(['bits-1', beginCell().storeUint(1, 1).endCell()]);

    // Maximum fan-out: 4 refs.
    cells.push([
        'four-refs',
        beginCell()
            .storeUint(0xaa, 8)
            .storeRef(beginCell().storeUint(1, 8).endCell())
            .storeRef(beginCell().storeUint(2, 8).endCell())
            .storeRef(beginCell().storeUint(3, 8).endCell())
            .storeRef(beginCell().storeUint(4, 8).endCell())
            .endCell(),
    ]);

    // Deep chain: exercises depth computation and topological ordering.
    let deep = beginCell().storeUint(0, 8).endCell();
    for (let i = 1; i <= 10; i++) {
        deep = beginCell().storeUint(i, 8).storeRef(deep).endCell();
    }
    cells.push(['depth-10-chain', deep]);

    // Shared subtree: the same cell referenced twice must be written once.
    const shared = beginCell().storeUint(0x1234, 16).endCell();
    cells.push(['shared-subtree', beginCell().storeRef(shared).storeRef(shared).endCell()]);

    // Wide tree: 4 refs each holding 4 refs.
    const wide = beginCell().storeUint(0, 8);
    for (let i = 0; i < 4; i++) {
        const mid = beginCell().storeUint(i, 8);
        for (let j = 0; j < 4; j++) mid.storeRef(beginCell().storeUint(i * 4 + j, 8).endCell());
        wide.storeRef(mid.endCell());
    }
    cells.push(['wide-tree-4x4', wide.endCell()]);

    // Real contract code — the largest and most structurally varied cells we handle.
    cells.push(['wallet-v5r1-code', WalletV5R1CodeCell]);
    cells.push(['wallet-v4r2-code', WalletV4R2CodeCell]);

    return cells.map(([label, cell]) => describeCell(label, cell));
}

/**
 * Exotic cells, built by hand. @ton/core validates these on construction, so any
 * case it rejects is recorded as unsupported rather than silently dropped —
 * that keeps the Swift side honest about what it does and does not need.
 */
function exoticVectors() {
    const out: unknown[] = [];
    const dummyHash = Buffer.alloc(32, 0x7a);

    const attempt = (label: string, build: () => Cell) => {
        try {
            out.push({ ...describeCell(label, build()), supported: true });
        } catch (error) {
            out.push({
                label,
                supported: false,
                reason: error instanceof Error ? error.message : String(error),
            });
        }
    };

    // Pruned branch: 0x01 | levelMask | hash[] | depth[]
    attempt('pruned-branch-level-1', () =>
        new Cell({
            exotic: true,
            bits: beginCell()
                .storeUint(0x01, 8)
                .storeUint(0x01, 8)
                .storeBuffer(dummyHash)
                .storeUint(3, 16)
                .endCell().bits,
        }),
    );

    // Library reference: 0x02 | hash
    attempt('library-cell', () =>
        new Cell({
            exotic: true,
            bits: beginCell().storeUint(0x02, 8).storeBuffer(dummyHash).endCell().bits,
        }),
    );

    // Merkle proof: 0x03 | hash | depth | 1 ref
    attempt('merkle-proof', () => {
        const inner = beginCell().storeUint(0xbeef, 16).endCell();
        return new Cell({
            exotic: true,
            bits: beginCell()
                .storeUint(0x03, 8)
                .storeBuffer(inner.hash())
                .storeUint(inner.depth(), 16)
                .endCell().bits,
            refs: [inner],
        });
    });

    /**
     * A merkle proof over a subtree that contains a pruned branch, so the proved cell
     * has level 1 and its hash(0) differs from hash(1).
     *
     * This is the only case that actually exercises the merkle child-level bump
     * (`c.hash(level + 1)` rather than `c.hash(level)`): with a level-0 subtree all four
     * stored hashes are identical and the bump is unobservable. Verified by mutation —
     * removing the bump leaves a level-0-only suite entirely green.
     */
    attempt('merkle-proof-over-pruned', () => {
        const prunedBits = beginCell()
            .storeUint(0x01, 8)
            .storeUint(0x01, 8)
            .storeBuffer(Buffer.alloc(32, 0x5c))
            .storeUint(7, 16)
            .endCell().bits;
        const pruned = new Cell({ exotic: true, bits: prunedBits });

        // Parent unions the pruned child's level mask, so parent.level() === 1.
        const parent = beginCell().storeUint(0xaa, 8).storeRef(pruned).endCell();

        return new Cell({
            exotic: true,
            bits: beginCell()
                .storeUint(0x03, 8)
                .storeBuffer(parent.hash(0))
                .storeUint(parent.depth(0), 16)
                .endCell().bits,
            refs: [parent],
        });
    });

    // Merkle update: 0x04 | hash1 | hash2 | depth1 | depth2 | 2 refs
    attempt('merkle-update', () => {
        const from = beginCell().storeUint(0x1111, 16).endCell();
        const to = beginCell().storeUint(0x2222, 16).endCell();
        return new Cell({
            exotic: true,
            bits: beginCell()
                .storeUint(0x04, 8)
                .storeBuffer(from.hash(0))
                .storeBuffer(to.hash(0))
                .storeUint(from.depth(0), 16)
                .storeUint(to.depth(0), 16)
                .endCell().bits,
            refs: [from, to],
        });
    });

    // A cell whose level is raised purely by referencing a pruned branch.
    attempt('ordinary-with-pruned-child', () => {
        const prunedBits = beginCell()
            .storeUint(0x01, 8)
            .storeUint(0x01, 8)
            .storeBuffer(Buffer.alloc(32, 0x33))
            .storeUint(2, 16)
            .endCell().bits;
        const pruned = new Cell({ exotic: true, bits: prunedBits });
        return beginCell().storeUint(0xcc, 8).storeRef(pruned).endCell();
    });

    return out;
}

// ── BitString rendering ──────────────────────────────────────────────────────

/**
 * `BitString.toString()` across every alignment class. The rules are unobvious:
 * nibble-aligned strings carry no completion marker, non-nibble-aligned ones do,
 * and the cut position depends on whether length % 8 exceeds 4. Generated rather
 * than hand-written, because hand-written expectations here were wrong once already.
 */
function bitStringVectors() {
    const cases: [number, number][] = [
        [0, 0],
        [1, 1],
        [0, 1],
        [0b101, 3],
        [0xa, 4],
        [0x0, 4],
        [0b10101, 5],
        [0b101010, 6],
        [0b1010101, 7],
        [0xab, 8],
        [0x1ab, 9],
        [0xabc, 12],
        [0xabcd, 16],
        [0x1abcd, 17],
    ];

    return cases.map(([value, bits]) => {
        const cell = bits === 0 ? beginCell().endCell() : beginCell().storeUint(value, bits).endCell();
        return {
            value: value.toString(),
            bitLength: bits,
            mod4: bits % 4,
            mod8: bits % 8,
            rendered: cell.bits.toString(),
        };
    });
}

// ── Address ──────────────────────────────────────────────────────────────────

const TEST_ADDRESSES = [
    '0:0000000000000000000000000000000000000000000000000000000000000000',
    '0:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    '0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8',
    '0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc',
    '-1:3333333333333333333333333333333333333333333333333333333333333333',
    '-1:5555555555555555555555555555555555555555555555555555555555555555',
];

function addressVectors() {
    const valid = TEST_ADDRESSES.map((raw) => {
        const addr = Address.parseRaw(raw);
        return {
            raw,
            workchain: addr.workChain,
            hash: hex(addr.hash),
            bounceable: addr.toString({ urlSafe: true, bounceable: true, testOnly: false }),
            nonBounceable: addr.toString({ urlSafe: true, bounceable: false, testOnly: false }),
            bounceableTestnet: addr.toString({ urlSafe: true, bounceable: true, testOnly: true }),
            nonBounceableTestnet: addr.toString({ urlSafe: true, bounceable: false, testOnly: true }),
            bounceableNonUrlSafe: addr.toString({ urlSafe: false, bounceable: true, testOnly: false }),
            // Round-trip through the friendly form to catch checksum errors.
            reparsedRaw: Address.parseFriendly(
                addr.toString({ urlSafe: true, bounceable: true, testOnly: false }),
            ).address.toRawString(),
        };
    });

    const invalid = [
        ['empty', ''],
        ['garbage', 'not-an-address'],
        ['bad-checksum', 'EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xaQ'],
        ['truncated-friendly', 'EQCD39VS5jcptHL8vMjEXrzGaRcCVYto'],
        ['raw-missing-workchain', 'abcdef'],
        ['raw-short-hash', '0:abcd'],
        ['raw-long-hash', `0:${'a'.repeat(66)}`],
        ['raw-non-hex', `0:${'z'.repeat(64)}`],
    ].map(([label, value]) => ({
        ...expectThrow(label, () => Address.parse(value)),
        input: value,
    }));

    return { valid, invalid };
}

// ── Dictionary (HashmapE) ────────────────────────────────────────────────────

function dictionaryVectors() {
    const out: unknown[] = [];

    const store = (label: string, build: () => Cell) => out.push({ label, ...cellSummary(build()) });
    const cellSummary = (cell: Cell) => ({ boc: b64(cell.toBoc()), hash: hex(cell.hash()) });

    // The V5R1 extensions shape: BigUint(256) -> BigInt(1).
    const extKeys = Dictionary.Keys.BigUint(256);
    const extVals = Dictionary.Values.BigInt(1);

    store('ext-empty', () => beginCell().storeDict(Dictionary.empty(extKeys, extVals), extKeys, extVals).endCell());

    store('ext-one-entry', () => {
        const d = Dictionary.empty(extKeys, extVals);
        d.set(1n, -1n);
        return beginCell().storeDict(d, extKeys, extVals).endCell();
    });

    store('ext-three-entries', () => {
        const d = Dictionary.empty(extKeys, extVals);
        d.set(1n, -1n);
        d.set(1n << 255n, -1n);
        d.set(0xdeadbeefn, -1n);
        return beginCell().storeDict(d, extKeys, extVals).endCell();
    });

    // Narrow keys exercise label encoding (short/long/same) differently.
    const u8 = Dictionary.Keys.Uint(8);
    const cellVals = Dictionary.Values.Cell();
    store('u8-to-cell-empty', () => beginCell().storeDict(Dictionary.empty(u8, cellVals), u8, cellVals).endCell());
    store('u8-to-cell-sparse', () => {
        const d = Dictionary.empty(u8, cellVals);
        d.set(0, beginCell().storeUint(0, 8).endCell());
        d.set(255, beginCell().storeUint(255, 8).endCell());
        return beginCell().storeDict(d, u8, cellVals).endCell();
    });
    store('u8-to-cell-dense-100', () => {
        const d = Dictionary.empty(u8, cellVals);
        for (let i = 0; i < 100; i++) d.set(i, beginCell().storeUint(i, 8).endCell());
        return beginCell().storeDict(d, u8, cellVals).endCell();
    });

    const u32 = Dictionary.Keys.Uint(32);
    const bu64 = Dictionary.Values.BigUint(64);
    store('u32-to-biguint64', () => {
        const d = Dictionary.empty(u32, bu64);
        d.set(1, 1n);
        d.set(0xffffffff, (1n << 64n) - 1n);
        d.set(1000, 12345678901234567890n);
        return beginCell().storeDict(d, u32, bu64).endCell();
    });

    // Address-keyed dictionaries appear in jetton/NFT contract data.
    const addrKeys = Dictionary.Keys.Address();
    store('address-to-cell', () => {
        const d = Dictionary.empty(addrKeys, cellVals);
        for (const raw of TEST_ADDRESSES.slice(0, 3)) {
            d.set(Address.parseRaw(raw), beginCell().storeUint(1, 8).endCell());
        }
        return beginCell().storeDict(d, addrKeys, cellVals).endCell();
    });

    return out;
}

// ── TL-B messages ────────────────────────────────────────────────────────────

function messageVectors() {
    const to = Address.parseRaw(TEST_ADDRESSES[2]);
    const from = Address.parseRaw(TEST_ADDRESSES[3]);
    const payload = beginCell().storeUint(0, 32).storeStringTail('hello').endCell();
    const stateInitCell = beginCell().storeUint(0b00110, 5).endCell();

    const relaxed: [string, MessageRelaxed][] = [
        ['internal-minimal', internal({ to, value: 0n, bounce: true })],
        ['internal-1-ton', internal({ to, value: 1_000_000_000n, bounce: true })],
        ['internal-non-bounceable', internal({ to, value: 100n, bounce: false })],
        ['internal-with-body', internal({ to, value: 100n, bounce: true, body: payload })],
        [
            'internal-with-init',
            internal({ to, value: 100n, bounce: true, body: payload, init: { code: stateInitCell, data: stateInitCell } }),
        ],
        [
            'internal-extracurrency',
            internal({ to, value: 100n, bounce: true, extracurrency: { 100: 1000n, 200: 2000n } }),
        ],
        ['internal-max-value', internal({ to, value: (1n << 120n) - 1n, bounce: true })],

        /**
         * State init present *and* a body too large to inline alongside it.
         *
         * This is the only shape that distinguishes storeMessage's init rule
         * (`availableBits - 2 < initCell.bits + body.bits`) from
         * storeMessageRelaxed's (`availableBits - 2 < initCell.bits`). A StateInit
         * cell holds code and data as refs, so its own payload is ~5 bits and the two
         * rules agree for every small body. Verified by mutation: without this case,
         * swapping one rule for the other leaves the suite green.
         */
        [
            'internal-init-with-large-body',
            internal({
                to,
                value: 100n,
                bounce: true,
                init: { code: stateInitCell, data: stateInitCell },
                body: beginCell().storeUint(0, 900).endCell(),
            }),
        ],
        [
            'internal-init-with-borderline-body',
            internal({
                to,
                value: 100n,
                bounce: true,
                init: { code: stateInitCell, data: stateInitCell },
                body: beginCell().storeUint(0, 600).endCell(),
            }),
        ],

        /**
         * An exotic body. storeMessageRelaxed refuses to inline one; storeMessage has
         * no such check. Without this case the `!body.isExotic` condition can be
         * deleted with the suite still green.
         */
        [
            'internal-exotic-body',
            internal({
                to,
                value: 100n,
                bounce: true,
                body: new Cell({
                    exotic: true,
                    bits: beginCell()
                        .storeUint(0x02, 8)
                        .storeBuffer(Buffer.alloc(32, 0x6b))
                        .endCell().bits,
                }),
            }),
        ],
    ];

    const relaxedOut = relaxed.map(([label, msg]) => {
        const cell = beginCell().store(storeMessageRelaxed(msg)).endCell();
        const forced = beginCell().store(storeMessageRelaxed(msg, { forceRef: true })).endCell();
        return {
            label,
            kind: 'relaxed',
            boc: b64(cell.toBoc()),
            hash: hex(cell.hash()),
            bocForceRef: b64(forced.toBoc()),
            hashForceRef: hex(forced.hash()),
            // Round-trip: Swift must parse and re-serialize to the same bytes.
            reserializedBoc: b64(
                beginCell().store(storeMessageRelaxed(loadMessageRelaxed(cell.beginParse()))).endCell().toBoc(),
            ),
        };
    });

    const full: [string, ReturnType<typeof external>][] = [
        ['external-in-empty', external({ to, body: beginCell().endCell() })],
        ['external-in-with-body', external({ to, body: payload })],
        [
            'external-in-with-init',
            external({ to, body: payload, init: { code: stateInitCell, data: stateInitCell } }),
        ],
    ];

    const fullOut = full.map(([label, msg]) => {
        const cell = beginCell().store(storeMessage(msg)).endCell();
        const forced = beginCell().store(storeMessage(msg, { forceRef: true })).endCell();
        return {
            label,
            kind: 'full',
            boc: b64(cell.toBoc()),
            hash: hex(cell.hash()),
            bocForceRef: b64(forced.toBoc()),
            hashForceRef: hex(forced.hash()),
            reserializedBoc: b64(
                beginCell().store(storeMessage(loadMessage(cell.beginParse()))).endCell().toBoc(),
            ),
        };
    });

    void from;
    return [...relaxedOut, ...fullOut];
}

// ── TVM tuples ───────────────────────────────────────────────────────────────

function tupleVectors() {
    const cell = beginCell().storeUint(0xcafe, 16).endCell();

    const cases: [string, RawStackItem[]][] = [
        ['empty', []],
        ['single-num-positive', [{ type: 'num', value: '42' }]],
        ['single-num-hex', [{ type: 'num', value: '0x2a' }]],
        ['single-num-negative', [{ type: 'num', value: '-42' }]],
        ['single-num-zero', [{ type: 'num', value: '0' }]],
        ['num-256-bit', [{ type: 'num', value: `0x${'f'.repeat(64)}` }]],
        ['null', [{ type: 'null' }]],
        ['cell', [{ type: 'cell', value: b64(cell.toBoc()) }]],
        [
            'tuple-nested',
            [
                {
                    type: 'tuple',
                    value: [
                        { type: 'num', value: '1' },
                        { type: 'tuple', value: [{ type: 'num', value: '2' }] },
                    ],
                },
            ],
        ],
        ['tuple-empty-becomes-null', [{ type: 'tuple', value: [] }]],
        ['list-empty-becomes-null', [{ type: 'list', value: [] }]],
        [
            'mixed-stack',
            [
                { type: 'num', value: '7' },
                { type: 'null' },
                { type: 'cell', value: b64(cell.toBoc()) },
            ],
        ],
    ];

    return cases.map(([label, input]) => ({
        label,
        input,
        parsed: ParseStack(input).map(function describe(item): unknown {
            switch (item.type) {
                case 'int':
                    return { type: 'int', value: item.value.toString() };
                case 'null':
                    return { type: 'null' };
                case 'cell':
                    return { type: 'cell', hash: hex(item.cell.hash()) };
                case 'slice':
                    return { type: 'slice', hash: hex(item.cell.hash()) };
                case 'tuple':
                    return { type: 'tuple', items: item.items.map(describe) };
                default:
                    return { type: (item as { type: string }).type };
            }
        }),
    }));
}

// ── Snake strings ────────────────────────────────────────────────────────────

/// `storeStringTail` fills the current cell and spills the remainder into a reference
/// chain. The boundary depends on what is already in the cell, so each case is emitted
/// both alone and after a 32-bit opcode — the shape a transfer comment actually takes.
function snakeStringVectors() {
    const texts = [
        '',
        'gm',
        'a'.repeat(126),
        'a'.repeat(127),
        'a'.repeat(128),
        'a'.repeat(200),
        'a'.repeat(500),
        'a'.repeat(2000),
        'спасибо 🙏 — 感谢',
        '\u0000 embedded nul',
    ];
    return texts.map((text) => ({
        label: `len-${Buffer.from(text).length}`,
        text,
        byteLength: Buffer.from(text).length,
        plainBoc: b64(beginCell().storeStringTail(text).endCell().toBoc()),
        commentBoc: b64(beginCell().storeUint(0, 32).storeStringTail(text).endCell().toBoc()),
    }));
}

export function dumpCore(): void {
    write('snake-strings.json', snakeStringVectors());
    write('bitstring.json', bitStringVectors());
    write('boc.json', bocVectors());
    write('boc-exotic.json', exoticVectors());
    write('address.json', addressVectors());
    write('dictionary.json', dictionaryVectors());
    write('messages.json', messageVectors());
    write('tuples.json', tupleVectors());
}
