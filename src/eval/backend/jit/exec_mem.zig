// SPDX-License-Identifier: EPL-2.0
//! Executable-memory primitive for the D-133 narrow ARM64 integer-loop JIT
//! (ADR-0151). The riskiest mechanical part of the JIT, spiked first per
//! ADR-0089: allocate a page, emit raw little-endian ARM64 u32 instructions
//! into it, flip it executable (W^X), flush the instruction cache, and hand
//! back a callable entry pointer.
//!
//! Lifecycle (compile-once, per ADR-0151 — NOT incremental W↔X toggling):
//!   1. `CodeBuffer.init(len)` mmaps one or more pages **RW**.
//!   2. `emit(word)` appends a 32-bit instruction (every ARM64 instruction is
//!      one little-endian u32).
//!   3. `finalize(Fn)` flips the page **RX** (`mprotect`), flushes the icache,
//!      and returns the typed entry pointer. After this the buffer is frozen.
//!   4. `deinit()` munmaps.
//!
//! W^X note (ADR-0151): the compile-once "mmap RW → mprotect RX" path is proven
//! on Apple Silicon (cw v0's jit.zig ships it). The `MAP_JIT` +
//! `pthread_jit_write_protect_np` toggle is only needed for repeated W↔X
//! patching, which a compile-once leaf does not do — deferred until a later
//! milestone needs it.
//!
//! ARM64-only: callers gate on `builtin.cpu.arch == .aarch64` (a non-aarch64
//! host runs the loop on the VM — the JIT is inert there, no behaviour change).

const std = @import("std");
const builtin = @import("builtin");

const PAGE_SIZE = std.heap.page_size_min;

pub const ExecMemError = error{ MmapFailed, MprotectFailed };

/// A page-aligned RW→RX code buffer. Holds the mmap'd region + the write
/// cursor; `finalize` freezes it and yields the entry pointer.
pub const CodeBuffer = struct {
    /// The mmap'd region (page-multiple length). Aligned to the page size so
    /// `mprotect` accepts it.
    buffer: []align(PAGE_SIZE) u8,
    /// Bytes written so far (always a multiple of 4 — one ARM64 word each).
    offset: usize = 0,
    /// Set by `finalize`; a second emit/finalize after freezing is a bug.
    frozen: bool = false,

    /// Reserve at least `min_bytes` of RW executable-capable memory (rounded up
    /// to a page multiple). One page is plenty for a leaf integer loop.
    pub fn init(min_bytes: usize) ExecMemError!CodeBuffer {
        const len = std.mem.alignForward(usize, @max(min_bytes, PAGE_SIZE), PAGE_SIZE);
        const mem = std.posix.mmap(
            null,
            len,
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        ) catch return error.MmapFailed;
        return .{ .buffer = @alignCast(mem) };
    }

    pub fn deinit(self: *CodeBuffer) void {
        std.posix.munmap(self.buffer);
        self.* = undefined;
    }

    /// Append one little-endian 32-bit ARM64 instruction. Caller ensures the
    /// page has room (a leaf loop is far under one page); an overflow is a
    /// compiler bug, surfaced as a safe-build bounds panic rather than silent
    /// corruption.
    pub fn emit(self: *CodeBuffer, word: u32) void {
        std.debug.assert(!self.frozen);
        std.mem.writeInt(u32, self.buffer[self.offset..][0..4], word, .little);
        self.offset += 4;
    }

    /// Freeze the buffer executable and return the entry pointer typed as `Fn`
    /// (a `*const fn (...) callconv(.c) ...`). After this the buffer is RX and
    /// no further `emit` is allowed. ARM64 requires an icache flush between the
    /// last write and the first execution.
    pub fn finalize(self: *CodeBuffer, comptime Fn: type) ExecMemError!Fn {
        const prot: std.posix.PROT = .{ .READ = true, .EXEC = true };
        if (std.c.mprotect(self.buffer.ptr, self.buffer.len, prot) != 0)
            return error.MprotectFailed;
        icacheInvalidate(self.buffer.ptr, self.offset);
        self.frozen = true;
        return @ptrCast(@alignCast(self.buffer.ptr));
    }
};

/// Flush the instruction cache for `[ptr, ptr+len)` — mandatory on ARM64 before
/// executing freshly written code (the D-cache write is not coherent with the
/// I-cache). macOS exposes `sys_icache_invalidate`; other ARM64 hosts use the
/// compiler builtin `__clear_cache`. Brought in via `@extern` (neither is in the
/// Zig 0.16 stdlib), the pattern cw v0 uses.
fn icacheInvalidate(ptr: [*]const u8, len: usize) void {
    if (builtin.os.tag == .macos) {
        const f = @extern(*const fn ([*]const u8, usize) callconv(.c) void, .{
            .name = "sys_icache_invalidate",
        });
        f(ptr, len);
    } else {
        const f = @extern(*const fn ([*]const u8, [*]const u8) callconv(.c) void, .{
            .name = "__clear_cache",
        });
        f(ptr, ptr + len);
    }
}

// --- ARM64 encoding helpers (only what the spike test needs; the codegen
//     milestone grows this set) ---

/// `MOVZ Xd, #imm16` (64-bit, no shift) — load a 16-bit immediate, zeroing the
/// rest. Base 0xD2800000 | (imm16 << 5) | Rd.
pub fn movzX(rd: u5, imm16: u16) u32 {
    return 0xD2800000 | (@as(u32, imm16) << 5) | rd;
}

/// `RET` (returns to X30, the link register). 0xD65F03C0.
pub fn ret() u32 {
    return 0xD65F03C0;
}

test "exec_mem: emit + call a trivial ARM64 leaf fn returning a constant" {
    if (builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var buf = try CodeBuffer.init(64);
    defer buf.deinit();
    // fn() -> u64 { return 42; }  =  movz x0, #42 ; ret
    buf.emit(movzX(0, 42));
    buf.emit(ret());
    const f = try buf.finalize(*const fn () callconv(.c) u64);
    try std.testing.expectEqual(@as(u64, 42), f());
}

test "exec_mem: a second emitted fn with a different constant" {
    if (builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var buf = try CodeBuffer.init(64);
    defer buf.deinit();
    buf.emit(movzX(0, 1337));
    buf.emit(ret());
    const f = try buf.finalize(*const fn () callconv(.c) u64);
    try std.testing.expectEqual(@as(u64, 1337), f());
}
