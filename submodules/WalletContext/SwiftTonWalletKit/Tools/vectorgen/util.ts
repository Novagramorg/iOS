/**
 * Shared helpers for the golden-vector generator.
 *
 * Everything emitted must be deterministic: no Date.now(), no Math.random(),
 * no mnemonicNew(). Re-running the generator on an unchanged walletkit checkout
 * must produce a byte-identical diff.
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

export const OUT_DIR = join(import.meta.dirname, '..', '..', 'Tests', 'TONTestVectors', 'Vectors');

/** Walletkit commit this vector set was generated from. Written into every file. */
export const SOURCE = '@ton/walletkit@1.1.0-beta.0';

export function write(name: string, payload: unknown): void {
    const path = join(OUT_DIR, name);
    mkdirSync(dirname(path), { recursive: true });
    const body = JSON.stringify({ source: SOURCE, vectors: payload }, jsonReplacer, 2);
    writeFileSync(path, body + '\n');
    console.log(`  ${name.padEnd(28)} ${String(countCases(payload)).padStart(4)} cases`);
    total += countCases(payload);
}

let total = 0;
export function totalCases(): number {
    return total;
}

/** Counts leaf cases, so files grouping arrays under keys don't report as "2 vectors". */
function countCases(payload: unknown): number {
    if (Array.isArray(payload)) return payload.length;
    if (payload && typeof payload === 'object') {
        return Object.values(payload).reduce<number>((sum, v) => sum + (Array.isArray(v) ? v.length : 0), 0);
    }
    return 0;
}

/** BigInt is not JSON-serializable; emit as a decimal string. */
function jsonReplacer(_key: string, value: unknown): unknown {
    if (typeof value === 'bigint') return value.toString();
    return value;
}

export function hex(buf: Buffer | Uint8Array): string {
    return Buffer.from(buf).toString('hex');
}

export function b64(buf: Buffer | Uint8Array): string {
    return Buffer.from(buf).toString('base64');
}

/**
 * Deterministic ed25519 seeds. Index i produces a 32-byte seed of repeated byte i,
 * so Swift tests can reconstruct the same keys without carrying them in the vectors.
 */
export function seed(i: number): Buffer {
    return Buffer.alloc(32, i);
}

/** Records a case that is expected to throw, so Swift asserts rejection rather than a value. */
export function expectThrow<T>(label: string, fn: () => T): { label: string; throws: true; message: string } {
    try {
        fn();
        throw new Error(`vectorgen: case "${label}" was expected to throw but returned normally`);
    } catch (error) {
        if (error instanceof Error && error.message.startsWith('vectorgen:')) throw error;
        return { label, throws: true, message: error instanceof Error ? error.message : String(error) };
    }
}
