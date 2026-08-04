/**
 * Records real Toncenter HTTP responses paired with the mapped models the reference
 * TypeScript client produces from them.
 *
 *   TONCENTER_KEY=... npx tsx record.ts [--testnet]
 *
 * Output: kit-swift/Tests/TONTestVectors/Fixtures/toncenter/<network>/*.json
 *
 * SECURITY: the API key must never reach disk. It is read from the environment,
 * stripped from every recorded request, and the serialized output is scanned for it
 * before writing — a hit aborts the run.
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

import { ApiClientToncenter } from '../../../kit-main/packages/walletkit/src/clients/toncenter/ApiClientToncenter.ts';
import { Network } from '../../../kit-main/packages/walletkit/src/api/models/core/Network.ts';

const TESTNET = process.argv.includes('--testnet');
const API_KEY = process.env.TONCENTER_KEY ?? '';

const OUT_DIR = join(
    import.meta.dirname,
    '..',
    '..',
    'Tests',
    'TONTestVectors',
    'Fixtures',
    'toncenter',
    TESTNET ? 'testnet' : 'mainnet',
);

if (!TESTNET && !API_KEY) {
    console.error('TONCENTER_KEY is required for mainnet recording (testnet works keyless).');
    process.exit(1);
}

// ── Recording fetch ──────────────────────────────────────────────────────────

interface RecordedRequest {
    method: string;
    /** Path + query only, with any api_key parameter removed. */
    url: string;
    status: number;
    /** Parsed JSON body, or the raw text when the response was not JSON. */
    body: unknown;
}

let captured: RecordedRequest[] = [];

const recordingFetch: typeof fetch = async (input, init) => {
    const response = await fetch(input, init);
    const text = await response.text();

    const raw = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    const parsed = new URL(raw);
    // Toncenter also accepts the key as a query parameter; drop it either way.
    parsed.searchParams.delete('api_key');
    parsed.searchParams.delete('X-API-Key');

    let body: unknown;
    try {
        body = JSON.parse(text);
    } catch {
        body = text;
    }

    captured.push({
        method: (init?.method ?? 'GET').toUpperCase(),
        url: parsed.pathname + (parsed.search || ''),
        status: response.status,
        body,
    });

    // Hand the client an equivalent response, since we already consumed the body.
    return new Response(text, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
    });
};

// ── Client ───────────────────────────────────────────────────────────────────

const network = TESTNET ? Network.testnet() : Network.mainnet();
const client = new ApiClientToncenter({
    network,
    apiKey: API_KEY || undefined,
    fetchApi: recordingFetch,
    timeout: 30_000,
});

// ── Case runner ──────────────────────────────────────────────────────────────

interface Fixture {
    label: string;
    method: string;
    args: unknown;
    requests: RecordedRequest[];
    mapped?: unknown;
    error?: { name: string; message: string };
}

const fixtures: Record<string, Fixture[]> = {};

async function record(
    file: string,
    label: string,
    method: string,
    args: unknown,
    run: () => Promise<unknown>,
): Promise<unknown> {
    captured = [];
    const entry: Fixture = { label, method, args, requests: [] };
    let result: unknown;
    try {
        result = await run();
        entry.mapped = result;
    } catch (error) {
        // Errors are fixtures too: the Swift client must fail the same way.
        entry.error = {
            name: error instanceof Error ? error.constructor.name : 'Unknown',
            message: error instanceof Error ? error.message : String(error),
        };
    }
    entry.requests = captured;
    (fixtures[file] ??= []).push(entry);

    // A 429 is not a behaviour worth recording — it is a fixture that lies. Fail the
    // run so nobody mistakes rate-limit noise for reference behaviour. Keyless testnet
    // hits this almost immediately; use a testnet-scoped key.
    if (entry.error && /HTTP 429/.test(entry.error.message)) {
        console.error(`\n  ${label}: rate limited (HTTP 429).`);
        console.error('  Recording aborted: supply a key valid for this network.');
        process.exit(1);
    }

    const status = entry.error ? `ERROR ${entry.error.name}` : 'ok';
    console.log(`  ${label.padEnd(46)} ${status}`);
    // Stay well inside the rate limit.
    await new Promise((r) => setTimeout(r, 220));
    return result;
}

// ── Account discovery ────────────────────────────────────────────────────────

/**
 * Seeds the recording from live chain data rather than a hardcoded list, so the
 * fixtures stay representative as the chain moves, and classifies accounts by state
 * so the active/uninit/non-existing cases are all genuinely covered.
 */
async function discoverAccounts(): Promise<{
    active: string[];
    uninit: string[];
    nonExisting: string[];
    withJettons: string[];
    withNfts: string[];
    jettonMasters: string[];
    walletAccount?: string;
    traceId?: string;
    txHash?: string;
}> {
    const base = TESTNET ? 'https://testnet.toncenter.com' : 'https://toncenter.com';
    const headers: Record<string, string> = { accept: 'application/json' };
    if (API_KEY) headers['x-api-key'] = API_KEY;

    const txs = await (await fetch(`${base}/api/v3/transactions?limit=64`, { headers })).json();
    const candidates: string[] = [
        ...new Set<string>((txs.transactions ?? []).map((t: { account: string }) => t.account)),
    ];

    const states = await (
        await fetch(
            `${base}/api/v3/accountStates?${candidates
                .slice(0, 50)
                .map((a) => `address=${encodeURIComponent(a)}`)
                .join('&')}`,
            { headers },
        )
    ).json();

    const active: string[] = [];
    const uninit: string[] = [];
    for (const s of states.accounts ?? []) {
        if (s.status === 'active') active.push(s.address);
        else if (s.status === 'uninit' || s.status === 'uninitialized') uninit.push(s.address);
    }

    // Basechain first. Masterchain system accounts (-1:5555 config, -1:3333 elector)
    // receive tick_tock transactions, which are structurally unlike ordinary ones and
    // which the reference mapper cannot handle at all — so they make a poor default
    // but an essential explicit case.
    active.sort((a, b) => Number(a.startsWith('-1:')) - Number(b.startsWith('-1:')));

    // An address that is valid but astronomically unlikely to exist.
    const nonExisting = ['0:' + 'de'.repeat(32)];

    // A real trace id and tx hash. getTrace() ignores request.account entirely and
    // only reads request.traceId, so without these there is no way to record a
    // successful trace response.
    let traceId: string | undefined;
    let txHash: string | undefined;
    {
        // Pick the *richest* trace available, not the first one. A single-transaction trace
        // decodes fine but exercises none of the tree building — the fan-out, the ordering,
        // the depth — which is the whole reason these fixtures exist.
        const t = await (await fetch(`${base}/api/v3/traces?limit=20`, { headers })).json();
        const traces: Array<{
            trace_id?: string;
            transactions_order?: string[];
        }> = t.traces ?? [];
        const richest = traces
            .filter((x) => x.trace_id && (x.transactions_order?.length ?? 0) > 0)
            .sort((a, b) => (b.transactions_order?.length ?? 0) - (a.transactions_order?.length ?? 0))[0];
        traceId = richest?.trace_id;
        txHash = richest?.transactions_order?.[0];
        console.log(`  discovery: richest trace has ${richest?.transactions_order?.length ?? 0} transactions`);
    }

    // An account whose `seqno` actually succeeds. Most contracts have no such method, so
    // recording get-methods against an arbitrary active account captures an exit code 11 and
    // proves nothing about reading a real stack.
    let walletAccount: string | undefined;
    for (const addr of active.slice(0, 20)) {
        const r = await (
            await fetch(`${base}/api/v3/runGetMethod`, {
                method: 'POST',
                headers: { ...headers, 'content-type': 'application/json' },
                body: JSON.stringify({ address: addr, method: 'seqno', stack: [] }),
            })
        ).json();
        if (r.exit_code === 0) {
            walletAccount = addr;
            break;
        }
        await new Promise((r2) => setTimeout(r2, 150));
    }
    console.log(`  discovery: wallet account for get-methods: ${walletAccount ?? 'none found'}`);

    // Find holders by asking the asset endpoints who owns things, rather than sampling
    // recently-active accounts and hoping. The old approach checked twelve accounts pulled
    // from the transaction feed; most hold neither jettons nor NFTs, so the recordings came
    // back empty and the fixtures proved nothing about the non-empty shape.
    const withJettons: string[] = [];
    const withNfts: string[] = [];
    const jettonMasters: string[] = [];

    // Basechain owners preferred: masterchain holders are unrepresentative of what a wallet
    // actually deals with.
    const preferBasechain = (a: string, b: string) =>
        Number(a.startsWith('-1:')) - Number(b.startsWith('-1:'));

    const jw = await (await fetch(`${base}/api/v3/jetton/wallets?limit=50`, { headers })).json();
    withJettons.push(
        ...[
            ...new Set<string>(
                (jw.jetton_wallets ?? [])
                    .map((w: { owner: string }) => w.owner)
                    .filter(Boolean),
            ),
        ].sort(preferBasechain),
    );

    const ni = await (await fetch(`${base}/api/v3/nft/items?limit=50`, { headers })).json();
    withNfts.push(
        ...[
            ...new Set<string>(
                (ni.nft_items ?? [])
                    .map((i: { owner_address: string }) => i.owner_address)
                    .filter(Boolean),
            ),
        ].sort(preferBasechain),
    );

    // A jetton *master*, which is a different thing from a holder. Passing an owner address
    // where a master is expected is why the masters fixture recorded empty on both networks.
    const jm = await (await fetch(`${base}/api/v3/jetton/masters?limit=20`, { headers })).json();
    jettonMasters.push(
        ...(jm.jetton_masters ?? [])
            .map((m: { address: string }) => m.address)
            .filter(Boolean)
            .sort(preferBasechain),
    );

    console.log(
        `  discovery: ${withJettons.length} jetton holders, ${withNfts.length} nft holders, ` +
            `${jettonMasters.length} jetton masters`,
    );

    return {
        active,
        uninit,
        nonExisting,
        withJettons,
        withNfts,
        jettonMasters,
        walletAccount,
        traceId,
        txHash,
    };
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
    console.log(`Recording Toncenter fixtures (${TESTNET ? 'testnet' : 'mainnet'})`);
    console.log(`Key: ${API_KEY ? 'present' : 'none (keyless)'}\n`);

    console.log('Discovering accounts...');
    const accounts = await discoverAccounts();
    console.log(
        `  active=${accounts.active.length} uninit=${accounts.uninit.length} ` +
            `withJettons=${accounts.withJettons.length} withNfts=${accounts.withNfts.length}\n`,
    );

    const activeAccount = accounts.active[0];
    if (!activeAccount) throw new Error('No active account discovered; cannot record fixtures');
    const jettonOwner = accounts.withJettons[0] ?? activeAccount;
    const nftOwner = accounts.withNfts[0] ?? activeAccount;
    const jettonMaster = accounts.jettonMasters[0];

    console.log('masterchainInfo:');
    await record('masterchain-info', 'masterchainInfo', 'getMasterchainInfo', {}, () =>
        client.getMasterchainInfo(),
    );

    console.log('\naccount states:');
    await record('account-state', 'active', 'getAccountState', { address: activeAccount }, () =>
        client.getAccountState(activeAccount as never),
    );
    await record(
        'account-state',
        'non-existing',
        'getAccountState',
        { address: accounts.nonExisting[0] },
        () => client.getAccountState(accounts.nonExisting[0] as never),
    );
    if (accounts.uninit[0]) {
        await record('account-state', 'uninit', 'getAccountState', { address: accounts.uninit[0] }, () =>
            client.getAccountState(accounts.uninit[0] as never),
        );
    }
    await record(
        'account-states',
        'batch-mixed',
        'getAccountStates',
        { addresses: [activeAccount, accounts.nonExisting[0]] },
        () => client.getAccountStates([activeAccount, accounts.nonExisting[0]] as never),
    );
    await record('balance', 'active', 'getBalance', { address: activeAccount }, () =>
        client.getBalance(activeAccount as never),
    );
    await record('balance', 'non-existing', 'getBalance', { address: accounts.nonExisting[0] }, () =>
        client.getBalance(accounts.nonExisting[0] as never),
    );

    console.log('\ntransactions:');
    await record(
        'transactions',
        'by-address-limit-5',
        'getAccountTransactions',
        { address: [activeAccount], limit: 5 },
        () => client.getAccountTransactions({ address: [activeAccount], limit: 5 }),
    );
    await record(
        'transactions',
        'by-address-non-existing',
        'getAccountTransactions',
        { address: [accounts.nonExisting[0]], limit: 5 },
        () => client.getAccountTransactions({ address: [accounts.nonExisting[0]], limit: 5 }),
    );
    await record(
        'transactions',
        'pending',
        'getPendingTransactions',
        { accounts: [activeAccount] },
        () => client.getPendingTransactions({ accounts: [activeAccount] }),
    );

    // tick_tock transactions: emitted to masterchain system accounts, carrying an
    // empty in_msg. The reference mapper throws on these ("Invalid hash: data is
    // required" from Base64ToHex on an undefined hash), so no account receiving them
    // can have its history listed. Recorded as a first-class case: the Swift port
    // must handle tick_tock rather than inherit the crash.
    const TICK_TOCK_ACCOUNT = '-1:5555555555555555555555555555555555555555555555555555555555555555';
    await record(
        'transactions',
        'tick-tock-masterchain-config',
        'getAccountTransactions',
        { address: [TICK_TOCK_ACCOUNT], limit: 5 },
        () => client.getAccountTransactions({ address: [TICK_TOCK_ACCOUNT], limit: 5 }),
    );

    console.log('\ntraces:');
    // Documented reference quirk: getTrace() ignores request.account and reads only
    // request.traceId, so this call issues three empty-valued requests and fails.
    // Recorded deliberately so the Swift port makes that behaviour a conscious choice.
    await record('traces', 'by-account-ignored-arg', 'getTrace', { account: activeAccount }, () =>
        client.getTrace({ account: activeAccount }),
    );

    if (accounts.traceId) {
        await record('traces', 'by-trace-id', 'getTrace', { traceId: [accounts.traceId] }, () =>
            client.getTrace({ traceId: [accounts.traceId!] }),
        );
    }
    if (accounts.txHash) {
        await record('traces', 'by-tx-hash', 'getTrace', { traceId: [accounts.txHash] }, () =>
            client.getTrace({ traceId: [accounts.txHash!] }),
        );
        await record(
            'transactions',
            'by-msg-hash',
            'getTransactionsByHash',
            { msgHash: accounts.txHash },
            () => client.getTransactionsByHash({ msgHash: accounts.txHash! }),
        );
    }
    await record(
        'traces',
        'pending-empty',
        'getPendingTrace',
        { externalMessageHash: ['00'.repeat(32)] },
        () => client.getPendingTrace({ externalMessageHash: ['00'.repeat(32)] }),
    );

    console.log('\nevents:');
    await record('events', 'by-account', 'getEvents', { account: activeAccount, limit: 3 }, () =>
        client.getEvents({ account: activeAccount, limit: 3 }),
    );

    console.log('\njettons:');
    await record(
        'jettons',
        'by-owner',
        'jettonsByOwnerAddress',
        { ownerAddress: jettonOwner, limit: 5 },
        () => client.jettonsByOwnerAddress({ ownerAddress: jettonOwner, limit: 5 }),
    );
    // A jetton master, not a holder — see the discovery note. Recording this with an owner
    // address produced an empty list that looked like a valid recording.
    if (jettonMaster) {
        await record(
            'jettons',
            'masters-by-address',
            'jettonsByAddress',
            { address: jettonMaster, limit: 5 },
            () => client.jettonsByAddress({ address: jettonMaster as never, limit: 5 }),
        );
    } else {
        console.log('  ! no jetton master discovered; skipping masters-by-address');
    }

    console.log('\nnfts:');
    await record('nfts', 'by-owner', 'nftItemsByOwner', { ownerAddress: nftOwner }, () =>
        client.nftItemsByOwner({ ownerAddress: nftOwner as never, pagination: { limit: 5, offset: 0 } }),
    );

    console.log('\nget-methods:');
    // A contract that answers `seqno`, so the success case records a real stack rather than
    // exit code 11 from a contract that has no such method.
    const getMethodAccount = accounts.walletAccount ?? activeAccount;
    await record(
        'get-method',
        'seqno',
        'runGetMethod',
        { address: getMethodAccount, method: 'seqno' },
        () => client.runGetMethod(getMethodAccount as never, 'seqno'),
    );
    await record(
        'get-method',
        'get-public-key',
        'runGetMethod',
        { address: getMethodAccount, method: 'get_public_key' },
        () => client.runGetMethod(getMethodAccount as never, 'get_public_key'),
    );
    await record(
        'get-method',
        'nonexistent-method',
        'runGetMethod',
        { address: getMethodAccount, method: 'definitely_not_a_method' },
        () => client.runGetMethod(getMethodAccount as never, 'definitely_not_a_method'),
    );

    console.log('\ndns:');
    await record('dns', 'resolve-known', 'resolveDnsWallet', { domain: 'ton.ton' }, () =>
        client.resolveDnsWallet('ton.ton'),
    );
    await record('dns', 'resolve-missing', 'resolveDnsWallet', { domain: 'zzz-nope-zzz.ton' }, () =>
        client.resolveDnsWallet('zzz-nope-zzz.ton'),
    );
    await record('dns', 'back-resolve', 'backResolveDnsWallet', { address: activeAccount }, () =>
        client.backResolveDnsWallet(activeAccount as never),
    );

    write();
}

// ── Output ───────────────────────────────────────────────────────────────────

function write(): void {
    mkdirSync(OUT_DIR, { recursive: true });

    let total = 0;
    console.log('\nWriting:');
    for (const [file, entries] of Object.entries(fixtures)) {
        const payload = {
            source: 'toncenter-v3',
            network: TESTNET ? 'testnet' : 'mainnet',
            recordedAt: null as string | null, // deliberately null: keeps diffs stable
            fixtures: entries,
        };
        // Mapped models carry BigInt token amounts, which JSON.stringify rejects.
        // Emit them as decimal strings — the Swift side decodes them the same way.
        const body = JSON.stringify(
            payload,
            (_key, value) => (typeof value === 'bigint' ? value.toString() : value),
            2,
        );

        // Fail closed: never write a file that contains the credential.
        if (API_KEY && body.includes(API_KEY)) {
            console.error(`\nABORT: API key leaked into ${file}.json — not writing anything.`);
            process.exit(1);
        }

        writeFileSync(join(OUT_DIR, `${file}.json`), body + '\n');
        console.log(`  ${`${file}.json`.padEnd(28)} ${String(entries.length).padStart(3)} fixtures`);
        total += entries.length;
    }
    console.log(`\nDone. ${total} fixtures across ${Object.keys(fixtures).length} files.`);
}

main().catch((error) => {
    console.error('\nRecording failed:');
    console.error(error);
    process.exit(1);
});
