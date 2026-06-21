;; Compute-heavy tight loop for the JIT-vs-interp demonstration: sumto(n) sums
;; 0..n-1 in i32 (wraps on overflow, identically on both engines). Built with
;; `wasm-tools parse bench/fixtures/sumto.wat -o bench/fixtures/sumto.wasm`.
(module
  (func (export "sumto") (param $n i32) (result i32)
    (local $i i32) (local $acc i32)
    (block $brk
      (loop $lp
        (br_if $brk (i32.ge_s (local.get $i) (local.get $n)))
        (local.set $acc (i32.add (local.get $acc) (local.get $i)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $lp)))
    (local.get $acc)))
