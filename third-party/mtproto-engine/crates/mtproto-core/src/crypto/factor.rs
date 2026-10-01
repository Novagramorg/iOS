pub fn factorize_pq(pq: u64) -> Option<(u64, u64)> {
    if pq < 4 {
        return None;
    }
    if pq.is_multiple_of(2) {
        return Some((2, pq / 2));
    }
    for seed in 1..64u64 {
        if let Some(divisor) = brent(pq, seed) {
            let other = pq / divisor;
            let (p, q) = if divisor < other { (divisor, other) } else { (other, divisor) };
            if p > 1 && p.checked_mul(q) == Some(pq) {
                return Some((p, q));
            }
        }
    }
    None
}

#[inline]
fn mul_mod(a: u64, b: u64, m: u64) -> u64 {
    ((a as u128 * b as u128) % m as u128) as u64
}

fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    a
}

fn brent(n: u64, c: u64) -> Option<u64> {
    let step = |x: u64| (mul_mod(x, x, n) + c) % n;
    let mut y = (c.wrapping_mul(0x9e37_79b9) + 2) % n;
    let batch = 128u64;
    let mut g = 1u64;
    let mut r = 1u64;
    let mut q = 1u64;
    let mut x = y;
    let mut ys = y;
    let limit = 1u64 << 26;
    while g == 1 {
        x = y;
        for _ in 0..r {
            y = step(y);
        }
        let mut k = 0u64;
        while k < r && g == 1 {
            ys = y;
            for _ in 0..batch.min(r - k) {
                y = step(y);
                q = mul_mod(q, x.abs_diff(y), n);
            }
            g = gcd(q, n);
            k += batch;
        }
        r *= 2;
        if r > limit {
            return None;
        }
    }
    if g == n {
        loop {
            ys = step(ys);
            g = gcd(x.abs_diff(ys), n);
            if g > 1 {
                break;
            }
        }
    }
    if g == n || g == 1 { None } else { Some(g) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn telegram_documentation_sample() {
        assert_eq!(factorize_pq(0x17ED48941A08F981), Some((0x494C553B, 0x53911073)));
    }

    #[test]
    fn small_and_degenerate_inputs() {
        assert_eq!(factorize_pq(0), None);
        assert_eq!(factorize_pq(3), None);
        assert_eq!(factorize_pq(15), Some((3, 5)));
        assert_eq!(factorize_pq(4), Some((2, 2)));
        assert_eq!(factorize_pq(10), Some((2, 5)));
    }

    #[test]
    fn products_of_large_32_bit_primes() {
        let primes: [u64; 8] =
            [4294967291, 4294967279, 4294967231, 4294967197, 2147483647, 1000000007, 1000000009, 998244353];
        for (i, &p) in primes.iter().enumerate() {
            for &q in &primes[i + 1..] {
                let (a, b) = if p < q { (p, q) } else { (q, p) };
                assert_eq!(factorize_pq(p * q), Some((a, b)), "{p} * {q}");
            }
        }
    }

    #[test]
    fn square_of_prime() {
        assert_eq!(factorize_pq(4294967291 * 4294967291), Some((4294967291, 4294967291)));
    }
}
