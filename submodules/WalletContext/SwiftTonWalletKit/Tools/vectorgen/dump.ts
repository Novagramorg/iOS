/**
 * Golden-vector generator for the native Swift WalletKit.
 *
 * Imports the reference TypeScript implementation directly from the pinned
 * walletkit checkout — nothing is copied, so the vectors cannot drift from the
 * reference by transcription error.
 *
 *   cd kit-swift/Tools/vectorgen && npx tsx dump.ts
 *
 * Output: kit-swift/Tests/Vectors/*.json
 */

import { dumpCore } from './sections/core.ts';
import { dumpCrypto } from './sections/crypto.ts';
import { dumpContracts } from './sections/contracts.ts';
import { dumpTonConnect } from './sections/tonconnect.ts';
import { OUT_DIR, SOURCE, totalCases } from './util.ts';

async function main(): Promise<void> {
    console.log(`Generating golden vectors from ${SOURCE}`);
    console.log(`Output: ${OUT_DIR}\n`);

    console.log('TONCore:');
    dumpCore();

    console.log('\nTONCrypto:');
    await dumpCrypto();

    console.log('\nTONContracts:');
    await dumpContracts();

    console.log('\nTONConnect:');
    dumpTonConnect();

    console.log(`\nDone. ${totalCases()} cases total.`);
    console.log('\nNote: Toncenter response fixtures are NOT generated here — they require');
    console.log('live recording against mainnet/testnet. See NATIVE_SWIFT_PLAN.md §4.1.');
}

main().catch((error) => {
    console.error('\nVector generation failed:');
    console.error(error);
    process.exit(1);
});
