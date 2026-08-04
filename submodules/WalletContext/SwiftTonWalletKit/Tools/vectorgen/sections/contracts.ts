/**
 * TONContracts vectors: wallet state init and address derivation, V5R1 action-list
 * packing, createBodyV5 payloads, V4R2 transfer bodies, TEP-467 normalized hashes.
 */

import { Address, beginCell, Dictionary, SendMode, external, internal, storeMessage } from '@ton/core';
import { keyPairFromSeed } from '@ton/crypto';

import {
    WalletV5,
    walletV5ConfigToCell,
    Opcodes,
} from '../../../../kit-main/packages/walletkit/src/contracts/w5/WalletV5R1.ts';
import { WalletV5R1CodeCell } from '../../../../kit-main/packages/walletkit/src/contracts/w5/WalletV5R1.source.ts';
import {
    WalletV5R1Adapter,
    defaultWalletIdV5R1,
} from '../../../../kit-main/packages/walletkit/src/contracts/w5/WalletV5R1Adapter.ts';
import {
    ActionSendMsg,
    ActionAddExtension,
    ActionRemoveExtension,
    ActionSetSignatureAuthAllowed,
    packActionsList,
} from '../../../../kit-main/packages/walletkit/src/contracts/w5/actions.ts';
import { WalletV4R2 } from '../../../../kit-main/packages/walletkit/src/contracts/v4r2/WalletV4R2.ts';
import { WalletV4R2CodeCell } from '../../../../kit-main/packages/walletkit/src/contracts/v4r2/WalletV4R2.source.ts';
import { defaultWalletIdV4R2 } from '../../../../kit-main/packages/walletkit/src/contracts/v4r2/constants.ts';
import { getNormalizedExtMessageHash } from '../../../../kit-main/packages/walletkit/src/utils/getNormalizedExtMessageHash.ts';
import { DefaultSignature } from '../../../../kit-main/packages/walletkit/src/utils/sign.ts';
import { b64, expectThrow, hex, seed, write } from '../util.ts';

const DEST = Address.parse('0:83dfd552e63729b472fcbcc8c45ebcc6691702558b68ec7527e1ba403a0f31a8');
const DEST2 = Address.parse('0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc');

/** The client is never called by the code paths we exercise, so a null stub is safe. */
const NULL_CLIENT = {} as never;

// ── State init and address derivation ────────────────────────────────────────

function stateInitVectors() {
    const out: unknown[] = [];

    for (let i = 0; i < 10; i++) {
        const kp = keyPairFromSeed(seed(i));
        const publicKey = BigInt('0x' + hex(kp.publicKey));

        for (const workchain of [0, -1]) {
            // V5R1: signatureAllowed(1) | seqno(32) | walletId(32) | publicKey(256) | extensions
            const v5Data = walletV5ConfigToCell({
                signatureAllowed: true,
                seqno: 0,
                walletId: defaultWalletIdV5R1,
                publicKey,
                extensions: Dictionary.empty(),
            });
            const v5 = WalletV5.createFromConfig(
                {
                    signatureAllowed: true,
                    seqno: 0,
                    walletId: defaultWalletIdV5R1,
                    publicKey,
                    extensions: Dictionary.empty(),
                },
                { code: WalletV5R1CodeCell, workchain, client: NULL_CLIENT },
            );

            out.push({
                version: 'v5r1',
                seedIndex: i,
                publicKey: hex(kp.publicKey),
                workchain,
                walletId: defaultWalletIdV5R1,
                dataBoc: b64(v5Data.toBoc()),
                dataHash: hex(v5Data.hash()),
                codeHash: hex(WalletV5R1CodeCell.hash()),
                address: v5.address.toRawString(),
                addressBounceable: v5.address.toString({ urlSafe: true, bounceable: true, testOnly: false }),
            });

            // V4R2: seqno(32) | subwalletId(32) | publicKey(256) | plugins(1 bit)
            const v4 = WalletV4R2.createFromConfig(
                { publicKey, workchain, seqno: 0, subwalletId: defaultWalletIdV4R2 },
                { code: WalletV4R2CodeCell, workchain, client: NULL_CLIENT },
            );
            out.push({
                version: 'v4r2',
                seedIndex: i,
                publicKey: hex(kp.publicKey),
                workchain,
                walletId: defaultWalletIdV4R2,
                dataBoc: b64(v4.init!.data.toBoc()),
                dataHash: hex(v4.init!.data.hash()),
                codeHash: hex(WalletV4R2CodeCell.hash()),
                address: v4.address.toRawString(),
                addressBounceable: v4.address.toString({ urlSafe: true, bounceable: true, testOnly: false }),
            });
        }
    }

    // Non-default walletIds change the address, so cover a few explicitly.
    for (const walletId of [0, 1, 2147483409, 698983191, 0x7fffffff]) {
        const kp = keyPairFromSeed(seed(0));
        const publicKey = BigInt('0x' + hex(kp.publicKey));
        const v5 = WalletV5.createFromConfig(
            { signatureAllowed: true, seqno: 0, walletId, publicKey, extensions: Dictionary.empty() },
            { code: WalletV5R1CodeCell, workchain: 0, client: NULL_CLIENT },
        );
        out.push({
            version: 'v5r1',
            seedIndex: 0,
            publicKey: hex(kp.publicKey),
            workchain: 0,
            walletId,
            dataBoc: b64(v5.init!.data.toBoc()),
            dataHash: hex(v5.init!.data.hash()),
            codeHash: hex(WalletV5R1CodeCell.hash()),
            address: v5.address.toRawString(),
            addressBounceable: v5.address.toString({ urlSafe: true, bounceable: true, testOnly: false }),
        });
    }

    return out;
}

/** Non-empty extensions dictionaries — a shape the default config never produces. */
function stateInitExtensionVectors() {
    const kp = keyPairFromSeed(seed(0));
    const publicKey = BigInt('0x' + hex(kp.publicKey));

    const build = (label: string, entries: [bigint, bigint][], signatureAllowed = true, seqno = 0) => {
        const extensions = Dictionary.empty(Dictionary.Keys.BigUint(256), Dictionary.Values.BigInt(1));
        for (const [k, v] of entries) extensions.set(k, v);
        const data = walletV5ConfigToCell({
            signatureAllowed,
            seqno,
            walletId: defaultWalletIdV5R1,
            publicKey,
            extensions,
        });
        return {
            label,
            signatureAllowed,
            seqno,
            entries: entries.map(([k, v]) => ({ key: k.toString(), value: v.toString() })),
            dataBoc: b64(data.toBoc()),
            dataHash: hex(data.hash()),
        };
    };

    return [
        build('no-extensions', []),
        build('one-extension', [[BigInt('0x' + '11'.repeat(32)), -1n]]),
        build('two-extensions', [
            [BigInt('0x' + '11'.repeat(32)), -1n],
            [BigInt('0x' + '22'.repeat(32)), -1n],
        ]),
        build('signature-disabled', [[BigInt('0x' + '11'.repeat(32)), -1n]], false),
        build('nonzero-seqno', [], true, 12345),
    ];
}

// ── Action lists ─────────────────────────────────────────────────────────────

function sendMsgAction(index: number) {
    return new ActionSendMsg(
        SendMode.PAY_GAS_SEPARATELY + SendMode.IGNORE_ERRORS,
        internal({ to: index % 2 === 0 ? DEST : DEST2, value: BigInt(1000 + index), bounce: true }),
    );
}

function actionVectors() {
    const out: unknown[] = [];

    const record = (label: string, actions: Parameters<typeof packActionsList>[0]) => {
        const cell = packActionsList(actions);
        out.push({ label, actionCount: actions.length, boc: b64(cell.toBoc()), hash: hex(cell.hash()) });
    };

    record('empty', []);
    record('one-send', [sendMsgAction(0)]);
    record('two-sends', [sendMsgAction(0), sendMsgAction(1)]);
    record('four-sends', [0, 1, 2, 3].map(sendMsgAction));

    // 255 is the protocol maximum and the deepest ref-chain the packer produces.
    record('255-sends', Array.from({ length: 255 }, (_, i) => sendMsgAction(i)));
    record('254-sends', Array.from({ length: 254 }, (_, i) => sendMsgAction(i)));

    record('add-extension-only', [new ActionAddExtension(DEST)]);
    record('remove-extension-only', [new ActionRemoveExtension(DEST)]);
    record('set-sig-auth-allowed-true', [new ActionSetSignatureAuthAllowed(true)]);
    record('set-sig-auth-allowed-false', [new ActionSetSignatureAuthAllowed(false)]);

    record('two-extended', [new ActionAddExtension(DEST), new ActionRemoveExtension(DEST2)]);
    record('three-extended', [
        new ActionAddExtension(DEST),
        new ActionRemoveExtension(DEST2),
        new ActionSetSignatureAuthAllowed(true),
    ]);

    // Mixed: extended actions are collected separately from out-actions regardless
    // of the order they were supplied in.
    record('mixed-send-then-extended', [sendMsgAction(0), new ActionAddExtension(DEST)]);
    record('mixed-extended-then-send', [new ActionAddExtension(DEST), sendMsgAction(0)]);
    record('mixed-many', [
        sendMsgAction(0),
        new ActionAddExtension(DEST),
        sendMsgAction(1),
        new ActionSetSignatureAuthAllowed(false),
        sendMsgAction(2),
    ]);

    // Individual action serialization, so a packing bug can be told apart from
    // an action-encoding bug.
    const individual = [
        ['send-msg', sendMsgAction(0)],
        ['add-extension', new ActionAddExtension(DEST)],
        ['remove-extension', new ActionRemoveExtension(DEST)],
        ['set-sig-auth-true', new ActionSetSignatureAuthAllowed(true)],
        ['set-sig-auth-false', new ActionSetSignatureAuthAllowed(false)],
    ].map(([label, action]) => {
        const cell = (action as { serialize(): ReturnType<typeof beginCell>['endCell'] extends never ? never : any }).serialize();
        return { label: label as string, boc: b64(cell.toBoc()), hash: hex(cell.hash()) };
    });

    return { packed: out, individual, opcodes: Opcodes };
}

// ── createBodyV5 ─────────────────────────────────────────────────────────────

function makeAdapter(options?: { walletId?: number; workchain?: number; domain?: unknown }) {
    const kp = keyPairFromSeed(seed(0));
    const secretKey = new Uint8Array(kp.secretKey);
    return new WalletV5R1Adapter({
        signer: {
            publicKey: `0x${hex(kp.publicKey)}`,
            sign: async (bytes: Iterable<number>) => DefaultSignature(bytes, secretKey),
        },
        publicKey: `0x${hex(kp.publicKey)}`,
        tonClient: NULL_CLIENT,
        network: { chainId: '-239' },
        walletId: options?.walletId,
        workchain: options?.workchain,
        domain: options?.domain as never,
    });
}

async function bodyV5Vectors() {
    const out: unknown[] = [];

    const cases = [
        { label: 'external-seqno-0', authType: 'external' as const, seqno: 0, validUntil: 1700000000, actions: 1 },
        { label: 'external-seqno-1', authType: 'external' as const, seqno: 1, validUntil: 1700000000, actions: 1 },
        { label: 'external-seqno-large', authType: 'external' as const, seqno: 0xfffffffe, validUntil: 1700000000, actions: 1 },
        { label: 'external-two-actions', authType: 'external' as const, seqno: 5, validUntil: 1700000000, actions: 2 },
        { label: 'external-four-actions', authType: 'external' as const, seqno: 5, validUntil: 1700000000, actions: 4 },
        { label: 'external-no-actions', authType: 'external' as const, seqno: 0, validUntil: 1700000000, actions: 0 },
        { label: 'internal-seqno-0', authType: 'internal' as const, seqno: 0, validUntil: 1700000000, actions: 1 },
        { label: 'internal-two-actions', authType: 'internal' as const, seqno: 3, validUntil: 1893456000, actions: 2 },
        { label: 'external-max-validuntil', authType: 'external' as const, seqno: 0, validUntil: 0xffffffff, actions: 1 },
    ];

    for (const c of cases) {
        const adapter = makeAdapter();
        const actions = Array.from({ length: c.actions }, (_, i) => sendMsgAction(i));
        const actionsList = packActionsList(actions);

        for (const fakeSignature of [false, true]) {
            const body = await adapter.createBodyV5(c.seqno, BigInt(defaultWalletIdV5R1), actionsList, {
                authType: c.authType,
                validUntil: c.validUntil,
                fakeSignature,
            });

            // The unsigned payload is what gets hashed and signed; emit it separately
            // so a signing bug is distinguishable from a serialization bug.
            const opcode = c.authType === 'internal' ? Opcodes.auth_signed_internal : Opcodes.auth_signed;
            const payload = beginCell()
                .storeUint(opcode, 32)
                .storeUint(BigInt(defaultWalletIdV5R1), 32)
                .storeUint(c.validUntil, 32)
                .storeUint(c.seqno, 32)
                .storeSlice(actionsList.beginParse())
                .endCell();

            out.push({
                label: `${c.label}${fakeSignature ? '-fake-sig' : ''}`,
                authType: c.authType,
                opcode,
                walletId: defaultWalletIdV5R1,
                seqno: c.seqno,
                validUntil: c.validUntil,
                actionCount: c.actions,
                actionsListBoc: b64(actionsList.toBoc()),
                payloadBoc: b64(payload.toBoc()),
                payloadHash: hex(payload.hash()),
                fakeSignature,
                signedBodyBoc: b64(body.toBoc()),
                signedBodyHash: hex(body.hash()),
            });
        }
    }

    // Signature-domain variants: prefix is prepended to the payload hash before signing.
    for (const domain of [{ type: 'empty' }, { type: 'l2', globalId: 1 }, { type: 'l2', globalId: -239 }]) {
        const adapter = makeAdapter({ domain });
        const actionsList = packActionsList([sendMsgAction(0)]);
        const body = await adapter.createBodyV5(0, BigInt(defaultWalletIdV5R1), actionsList, {
            authType: 'external',
            validUntil: 1700000000,
            fakeSignature: false,
        });
        out.push({
            label: `signature-domain-${domain.type}${'globalId' in domain ? `-${domain.globalId}` : ''}`,
            signatureDomain: domain,
            authType: 'external',
            seqno: 0,
            validUntil: 1700000000,
            actionsListBoc: b64(actionsList.toBoc()),
            signedBodyBoc: b64(body.toBoc()),
            signedBodyHash: hex(body.hash()),
        });
    }

    return out;
}

// ── V4R2 transfer bodies ─────────────────────────────────────────────────────

function v4TransferVectors() {
    const kp = keyPairFromSeed(seed(0));
    const publicKey = BigInt('0x' + hex(kp.publicKey));
    const wallet = WalletV4R2.createFromConfig(
        { publicKey, workchain: 0, seqno: 0, subwalletId: defaultWalletIdV4R2 },
        { code: WalletV4R2CodeCell, workchain: 0, client: NULL_CLIENT },
    );

    const cases = [
        { label: 'one-message', seqno: 0, timeout: 1700000000, count: 1 },
        { label: 'two-messages', seqno: 1, timeout: 1700000000, count: 2 },
        { label: 'four-messages', seqno: 7, timeout: 1893456000, count: 4 },
        { label: 'no-messages', seqno: 0, timeout: 1700000000, count: 0 },
    ];

    return cases.map((c) => {
        const messages = Array.from({ length: c.count }, (_, i) =>
            internal({ to: i % 2 === 0 ? DEST : DEST2, value: BigInt(1000 + i), bounce: true }),
        );
        const cell = wallet.createTransfer({
            seqno: c.seqno,
            sendMode: SendMode.PAY_GAS_SEPARATELY + SendMode.IGNORE_ERRORS,
            messages,
            timeout: c.timeout,
        });
        return {
            label: c.label,
            subwalletId: defaultWalletIdV4R2,
            seqno: c.seqno,
            timeout: c.timeout,
            sendMode: SendMode.PAY_GAS_SEPARATELY + SendMode.IGNORE_ERRORS,
            messageCount: c.count,
            boc: b64(cell.toBoc()),
            hash: hex(cell.hash()),
        };
    });
}

// ── TEP-467 normalized external message hash ─────────────────────────────────

async function normalizedHashVectors() {
    const out: unknown[] = [];

    // Realistic signed external messages, assembled from createBodyV5 output rather
    // than via adapter.getSignedSendTransaction() — the latter clamps validUntil
    // against Date.now(), which would make these vectors non-deterministic.
    for (const walletId of [defaultWalletIdV5R1, 0]) {
        for (const actionCount of [1, 2]) {
            const adapter = makeAdapter({ walletId });
            const actionsList = packActionsList(
                Array.from({ length: actionCount }, (_, i) => sendMsgAction(i)),
            );
            const body = await adapter.createBodyV5(0, BigInt(walletId), actionsList, {
                authType: 'external',
                validUntil: 1700000000,
                fakeSignature: true,
            });
            const ext = external({
                to: adapter.walletContract.address,
                init: adapter.walletContract.init,
                body,
            });
            const boc = b64(beginCell().store(storeMessage(ext)).endCell().toBoc());
            const normalized = getNormalizedExtMessageHash(boc);
            out.push({
                label: `signed-v5r1-walletid-${walletId}-actions-${actionCount}`,
                // Includes a state init, which the normalizer must strip.
                hasStateInit: true,
                inputBoc: boc,
                normalizedHash: normalized.hash,
                normalizedBoc: normalized.boc,
            });

            // Same message without the state init (the deployed-wallet case).
            const extNoInit = external({ to: adapter.walletContract.address, body });
            const bocNoInit = b64(beginCell().store(storeMessage(extNoInit)).endCell().toBoc());
            const normalizedNoInit = getNormalizedExtMessageHash(bocNoInit);
            out.push({
                label: `signed-v5r1-walletid-${walletId}-actions-${actionCount}-no-init`,
                hasStateInit: false,
                inputBoc: bocNoInit,
                normalizedHash: normalizedNoInit.hash,
                normalizedBoc: normalizedNoInit.boc,
            });
        }
    }

    // Hand-built external messages covering both body placements. The ext_in header
    // is ~277 bits, so a body over ~746 bits cannot be inlined and must be a ref —
    // and the normalizer has to handle both encodings identically.
    const handBuilt: [string, ReturnType<typeof beginCell>['endCell'] extends never ? never : any, boolean][] = [
        ['external-empty-body-inline', beginCell().endCell(), false],
        ['external-small-body-inline', beginCell().storeUint(0xdeadbeef, 32).endCell(), false],
        ['external-small-body-as-ref', beginCell().storeUint(0xdeadbeef, 32).endCell(), true],
        ['external-large-body-as-ref', beginCell().storeUint(0, 900).endCell(), true],
        ['external-max-body-as-ref', beginCell().storeUint(0, 1023).endCell(), true],
    ];

    for (const [label, body, bodyAsRef] of handBuilt) {
        const builder = beginCell()
            .storeUint(0b10, 2) // ext_in_msg_info
            .storeUint(0, 2) // src: addr_none
            .storeAddress(DEST) // dest
            .storeCoins(0) // import_fee
            .storeBit(false); // no init

        if (bodyAsRef) {
            builder.storeBit(true).storeRef(body);
        } else {
            builder.storeBit(false).storeSlice(body.beginParse());
        }

        const boc = b64(builder.endCell().toBoc());
        const normalized = getNormalizedExtMessageHash(boc);
        out.push({
            label,
            bodyAsRef,
            inputBoc: boc,
            normalizedHash: normalized.hash,
            normalizedBoc: normalized.boc,
        });
    }

    // Non-external-in messages must be rejected.
    const rejections = [
        expectThrow('internal-message-rejected', () =>
            getNormalizedExtMessageHash(
                b64(
                    beginCell()
                        .storeUint(0, 1) // int_msg_info
                        .storeBit(false)
                        .storeBit(true)
                        .storeBit(false)
                        .storeUint(0, 2)
                        .storeAddress(DEST)
                        .storeCoins(100)
                        .storeBit(false)
                        .storeCoins(0)
                        .storeCoins(0)
                        .storeUint(0, 64)
                        .storeUint(0, 32)
                        .storeBit(false)
                        .storeBit(false)
                        .endCell()
                        .toBoc(),
                ),
            ),
        ),
        expectThrow('garbage-boc-rejected', () => getNormalizedExtMessageHash('not-base64-at-all!!!')),
    ];

    return { valid: out, invalid: rejections };
}

export async function dumpContracts(): Promise<void> {
    write('stateinit.json', stateInitVectors());
    write('stateinit-extensions.json', stateInitExtensionVectors());
    write('actions.json', actionVectors());
    write('bodyv5.json', await bodyV5Vectors());
    write('v4r2-transfer.json', v4TransferVectors());
    write('normalized-hash.json', await normalizedHashVectors());
}
