// SPDX-License-Identifier: EPL-2.0
//! Fast pseudo-random generator — namespace-neutral implementation
//! per F-009.
//!
//! Two surfaces consume this file:
//!   1. `runtime/java/util/Random.zig` — `java.util.Random`
//!      (seedable, deterministic given the seed).
//!   2. `clojure.core/rand` / `rand-int`, implemented as the
//!      `rand` / `randInt` primitives in `lang/primitive/math.zig`,
//!      which draw from this file's lazily-seeded process PRNG.
//!
//! Cryptographic randomness (CSPRNG) is NOT here — it goes through
//! `std.Io.randomSecure` directly. A dedicated
//! `runtime/crypto/secure_random.zig` would be a future surface if
//! `java.security.SecureRandom` support grows.

const std = @import("std");

/// Re-export of Zig's reasonable default PRNG. Callers that need a
/// seedable / replayable random stream allocate one of these
/// directly (e.g. `var prng = Prng.init(seed);`).
pub const Prng = std.Random.DefaultPrng;

/// Process-wide non-secure PRNG for `(rand)` / `(rand-int n)`-style
/// random number consumers that don't need seed control. Seeded once
/// from a fresh kernel-random source at first access. Thread-local so
/// concurrent `(rand)` calls don't fight over a single mutex.
threadlocal var process_prng: ?Prng = null;

fn lazyPrng(io: std.Io) *Prng {
    if (process_prng == null) {
        var seed: u64 = 0;
        var seed_bytes: [8]u8 = undefined;
        std.Io.randomSecure(io, &seed_bytes) catch std.Io.random(io, &seed_bytes);
        seed = std.mem.readInt(u64, &seed_bytes, .little);
        process_prng = Prng.init(seed);
    }
    return &process_prng.?;
}

/// Returns `[0, bound)` non-negative i32. `bound` must be > 0.
pub fn nextIntBound(io: std.Io, bound: i32) i32 {
    std.debug.assert(bound > 0);
    return @intCast(lazyPrng(io).random().intRangeLessThan(u32, 0, @intCast(bound)));
}

/// Returns a uniform-random double in `[0.0, 1.0)`. Matches
/// `java.util.Random.nextDouble`.
pub fn nextDouble(io: std.Io) f64 {
    return lazyPrng(io).random().float(f64);
}

/// A full-width entropy `u64` from the process PRNG — the 0-arg
/// `(java.util.Random.)` seed source (non-reproducible by design, like clj).
pub fn entropyU64(io: std.Io) u64 {
    return lazyPrng(io).random().int(u64);
}

// --- java.util.Random LCG (ADR-0106 / D-289) ---
//
// Java's documented 48-bit linear congruential generator, implemented
// bit-exact for F-011 parity (data.generators reproducibility). Pure functions
// over a `*u64` seed (the host-instance state[0]); the surface
// (runtime/java/util/Random.zig) owns the HostInstance + cljw value boxing.
// Distinct from the DefaultPrng above (clojure.core/rand — no parity need).

const JAVA_MULT: u64 = 0x5DEECE66D;
const JAVA_ADD: u64 = 0xB;
const JAVA_MASK: u64 = (1 << 48) - 1;

/// Initial seed scramble (`new Random(s)` / `setSeed(s)`).
pub fn javaScramble(s: i64) u64 {
    return (@as(u64, @bitCast(s)) ^ JAVA_MULT) & JAVA_MASK;
}

/// `next(bits)`: advance the LCG, return the top `bits` bits as a signed i32.
/// `bits` ∈ 1..32. Wrapping arithmetic matches the JVM's overflow semantics.
pub fn javaNext(seed: *u64, bits: u6) i32 {
    seed.* = (seed.* *% JAVA_MULT +% JAVA_ADD) & JAVA_MASK;
    const sh: u6 = @intCast(48 - @as(u32, bits));
    return @bitCast(@as(u32, @truncate(seed.* >> sh)));
}

pub fn javaNextInt(seed: *u64) i32 {
    return javaNext(seed, 32);
}

/// `nextLong` = `((long)next(32) << 32) + next(32)` (both i32 sign-extended).
pub fn javaNextLong(seed: *u64) i64 {
    const hi: i64 = javaNext(seed, 32);
    const lo: i64 = javaNext(seed, 32);
    return (hi << 32) +% lo;
}

/// `nextDouble` = `((next(26) << 27) + next(27)) / 2^53` ∈ [0,1).
pub fn javaNextDouble(seed: *u64) f64 {
    const hi: i64 = javaNext(seed, 26);
    const lo: i64 = javaNext(seed, 27);
    return @as(f64, @floatFromInt((hi << 27) +% lo)) / 9007199254740992.0;
}

/// `nextFloat` = `next(24) / 2^24` computed in f32 (clj parity: Java returns a
/// float), then widened to cljw's f64 (F-005: single-f64 tower, no f32 type).
pub fn javaNextFloat(seed: *u64) f64 {
    const n: i32 = javaNext(seed, 24);
    const f: f32 = @as(f32, @floatFromInt(n)) / 16777216.0;
    return @as(f64, f);
}

pub fn javaNextBoolean(seed: *u64) bool {
    return javaNext(seed, 1) != 0;
}

/// `nextInt(bound)` with the exact JVM power-of-two fast path + rejection loop.
/// Caller guarantees `bound > 0`.
pub fn javaNextIntBound(seed: *u64, bound: i32) i32 {
    if ((bound & (0 -% bound)) == bound) { // power of two
        return @intCast((@as(i64, bound) *% @as(i64, javaNext(seed, 31))) >> 31);
    }
    while (true) {
        const bits = javaNext(seed, 31);
        const val = @mod(bits, bound);
        if (bits -% val +% (bound - 1) >= 0) return val;
    }
}

// --- tests ---

const testing = std.testing;

test "java.util.Random LCG matches the JVM oracle (seed 42 / 0)" {
    // Each from a FRESH seed-42 generator (oracle-confirmed, survey §1).
    {
        var s = javaScramble(42);
        try testing.expectEqual(@as(i32, -1170105035), javaNextInt(&s));
    }
    { // nextInt 6-element sequence
        var s = javaScramble(42);
        const want = [_]i32{ -1170105035, 234785527, -1360544799, 205897768, 1325939940, -248792245 };
        for (want) |w| try testing.expectEqual(w, javaNextInt(&s));
    }
    {
        var s = javaScramble(42);
        try testing.expectEqual(@as(i64, -5025562857975149833), javaNextLong(&s));
    }
    {
        var s = javaScramble(42);
        try testing.expectEqual(@as(f64, 0.7275636800328681), javaNextDouble(&s));
    }
    {
        var s = javaScramble(42);
        try testing.expectEqual(@as(f64, @as(f32, 0.7275637)), javaNextFloat(&s));
    }
    {
        var s = javaScramble(42);
        try testing.expect(javaNextBoolean(&s) == true);
    }
    {
        var s = javaScramble(42);
        try testing.expectEqual(@as(i32, 30), javaNextIntBound(&s, 100));
    }
    {
        var s = javaScramble(0);
        try testing.expectEqual(@as(i32, 360), javaNextIntBound(&s, 1000));
    }
}

test "nextIntBound stays within [0, bound)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const v = nextIntBound(th.io(), 100);
        try testing.expect(v >= 0 and v < 100);
    }
}

test "nextDouble stays within [0.0, 1.0)" {
    var th = std.Io.Threaded.init(testing.allocator, .{});
    defer th.deinit();
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const v = nextDouble(th.io());
        try testing.expect(v >= 0.0 and v < 1.0);
    }
}
