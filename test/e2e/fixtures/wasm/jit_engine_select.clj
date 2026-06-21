;; ADR-0200 JIT-engine adoption — cljw selects the zwasm engine per-instance via
;; `(wasm/load path {:engine :jit/:interp/:auto})`. The module exports a GPR `add`
;; (multi-arg) and a SIMD-body `lane0` (i32x4.extract_lane on a v128.const → 42;
;; SIMD executes JIT-compiled and crosses the scalar boundary).
;;
;; Asserts: (1) the GPR export is byte-identical under :jit and :interp — the F-012
;; differential discipline applied to engine choice; (2) the SIMD export runs on
;; :jit → 42 (end-to-end through wasm/call, which reads exportFuncSig — the JIT arm
;; zwasm shipped @5b6449779 / from_cljw_02); (3) the SIMD export traps a CATCHABLE
;; error on :interp (SIMD is JIT-only in zwasm — confirmed intentional, to_cljw_03);
;; (4) the no-opts default rides :interp and works (regression guard — zwasm reverted
;; the .auto→JIT flip, so the default must not break wasm/call).
(def w "test/e2e/fixtures/wasm/jit_simd.wasm")

(def jit    (wasm/load w {:engine :jit}))
(def interp (wasm/load w {:engine :interp}))

(println "add-jit:"    (wasm/call jit "add" 2 3))
(println "add-interp:" (wasm/call interp "add" 2 3))
(println "lane0-jit:"  (wasm/call jit "lane0"))
(println "lane0-interp:"
  (try (wasm/call interp "lane0") "RAN"
    (catch Throwable _ "TRAPPED")))
(println "default:" (wasm/call (wasm/load w) "add" 2 3))
(println "DONE")
