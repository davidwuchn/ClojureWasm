;; 3-arg FP export — locks the "3-arg via the generic buffer path" claim (to_cljw_05):
;; (f64,f64,f64)→f64, sum. Built with `wasm-tools parse three_f64.wat -o three_f64.wasm`.
(module (func (export "sum3") (param f64 f64 f64) (result f64)
  (f64.add (f64.add (local.get 0) (local.get 1)) (local.get 2))))
