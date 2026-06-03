;; clojure.math — thin Clojure wrappers over the host `Math` static methods
;; (D-232). cljw resolves `Math/*` interop without reflection, so each fn is a
;; one-line delegate. The common subset (trig / exp-log / roots / rounding /
;; angle conversion + PI/E) is covered; the exotic IEEE-754 helpers (ulp /
;; scalb / next-after / get-exponent / copy-sign / *-exact / floor-div…) are
;; deferred until a real need or the matching host method lands.
;;
;; Loaded by bootstrap.zig after core.clj. The (in-ns) header is mandatory.

(ns clojure.math (:refer-clojure))

(def ^:const PI Math/PI)
(def ^:const E Math/E)

(defn sin [a] (Math/sin a))
(defn cos [a] (Math/cos a))
(defn tan [a] (Math/tan a))
(defn asin [a] (Math/asin a))
(defn acos [a] (Math/acos a))
(defn atan [a] (Math/atan a))
(defn atan2 [y x] (Math/atan2 y x))
(defn to-radians [deg] (Math/toRadians deg))
(defn to-degrees [r] (Math/toDegrees r))

(defn exp [a] (Math/exp a))
(defn log [a] (Math/log a))
(defn log10 [a] (Math/log10 a))

(defn sqrt [a] (Math/sqrt a))
(defn cbrt [a] (Math/cbrt a))
(defn pow [a b] (Math/pow a b))
(defn hypot [x y] (Math/hypot x y))

(defn ceil [a] (Math/ceil a))
(defn floor [a] (Math/floor a))
;; rint (round-half-to-even) deferred — cljw's host Math lacks `rint` (D-232).
(defn round [a] (Math/round a))
(defn signum [a] (Math/signum a))
