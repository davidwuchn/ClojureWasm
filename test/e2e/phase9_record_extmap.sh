#!/usr/bin/env bash
# test/e2e/phase9_record_extmap.sh
#
# D-086 / ADR-0154 — defrecord `__extmap`: a non-declared key assoc'd onto a
# record is held in an extmap (clj parity), so the record stays a record and
# every IPersistentMap op (assoc / dissoc / get / contains? / keys / vals /
# count / seq / = / hash / map->R) honours the extra keys. Layer 2 (e2e CLI).
# The `#R{…}` print form omits clj's `user.` ns prefix (D-058/D-079, separate).

set -euo pipefail
cd "$(dirname "$0")/../.."

BIN="$(pwd)/zig-out/bin/cljw"
[ -n "${CLJW_SKIP_BUILD:-}" ] || zig build -Dwasm -Doptimize="${CLJW_OPT:-ReleaseSafe}" >/dev/null

fail() { echo "FAIL $1" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- assoc / map->R / read paths / equality / hash over extmap ---
cat > "$WORK/ext.clj" <<'EOF'
(defrecord R [x y])
(def re (assoc (->R 1 2) :z 9))
(assert (record? re))                         ; assoc-extra keeps record-ness
(assert (= 3 (count re)))                     ; field_count + extmap size
(assert (= 9 (get re :z)))                    ; get sees extmap
(assert (= 9 (:z re)))                         ; keyword-as-fn agrees
(assert (= 1 (:x re)))                         ; declared field intact
(assert (contains? re :z))                    ; contains? sees extmap
(assert (= '(:x :y :z) (keys re)))            ; declared-order then extmap
(assert (= '(1 2 9) (vals re)))
(assert (= '([:x 1] [:y 2] [:z 9]) (seq re))) ; seq entries declared-then-extmap
(assert (= re (assoc (->R 1 2) :z 9)))        ; extmap part of value equality
(assert (not= re (->R 1 2)))                  ; differs from no-extra record
(assert (= (assoc (->R 1 2) :a 1 :b 2)        ; order-independent equality
           (assoc (->R 1 2) :b 2 :a 1)))
(assert (= (hash (assoc (->R 1 2) :a 1 :b 2)) ; ...and hash
           (hash (assoc (->R 1 2) :b 2 :a 1))))
(assert (= re (map->R {:x 1 :y 2 :z 9})))     ; map->R keeps the extra key
(assert (= (assoc (->R 1 2) :z 9 :w 8)        ; multi-pair assoc folds
           (map->R {:x 1 :y 2 :z 9 :w 8})))
(println "OK record-extmap")
EOF
got="$("$BIN" "$WORK/ext.clj" 2>&1 | grep '^OK' || true)"
[[ "$got" == "OK record-extmap" ]] || fail "extmap: got '$("$BIN" "$WORK/ext.clj" 2>&1 | tail -4)'"
echo "PASS record_extmap_assoc_read_equality"

# --- dissoc: extmap key removed → normalize to nil; declared key demotes to map ---
cat > "$WORK/dis.clj" <<'EOF'
(defrecord R [x y])
(def re (assoc (->R 1 2) :z 9))
(def back (dissoc re :z))
(assert (record? back))                       ; dropping the only extra → record
(assert (= (->R 1 2) back))                   ; empty extmap normalizes to nil
(assert (= 2 (count back)))
(def demoted (dissoc re :x))                  ; dissoc a DECLARED key →
(assert (not (record? demoted)))              ; demotes to a plain map
(assert (= {:y 2 :z 9} demoted))              ; ...with extmap folded in
(assert (= re (dissoc re :nope)))             ; dissoc absent key → unchanged
(println "OK record-extmap-dissoc")
EOF
got="$("$BIN" "$WORK/dis.clj" 2>&1 | grep '^OK' || true)"
[[ "$got" == "OK record-extmap-dissoc" ]] || fail "dissoc: got '$("$BIN" "$WORK/dis.clj" 2>&1 | tail -4)'"
echo "PASS record_extmap_dissoc"

# --- print: extmap entries after declared fields (cljw `#R{…}`, no ns prefix) ---
cat > "$WORK/pr.clj" <<'EOF'
(defrecord R [x y])
(pr (assoc (->R 1 2) :z 9))
EOF
got="$("$BIN" "$WORK/pr.clj" 2>&1)"
[[ "$got" == '#R{:x 1, :y 2, :z 9}' ]] || fail "print: got '$got'"
echo "PASS record_extmap_print"

# --- meta survives an extmap assoc; extmap survives with-meta ---
cat > "$WORK/meta.clj" <<'EOF'
(defrecord R [x y])
(def rm (with-meta (->R 1 2) {:m 1}))
(def re (assoc rm :z 9))
(assert (= {:m 1} (meta re)))                 ; meta threads through extmap assoc
(assert (= 9 (get re :z)))
(def rme (with-meta (assoc (->R 1 2) :z 9) {:m 2}))
(assert (= 9 (get rme :z)))                   ; extmap survives with-meta
(assert (= {:m 2} (meta rme)))
(println "OK record-extmap-meta")
EOF
got="$("$BIN" "$WORK/meta.clj" 2>&1 | grep '^OK' || true)"
[[ "$got" == "OK record-extmap-meta" ]] || fail "meta+extmap: got '$("$BIN" "$WORK/meta.clj" 2>&1 | tail -4)'"
echo "PASS record_extmap_meta_interaction"

# --- conj / into on a record: [k v] / map-entry / map → assoc into extmap ---
cat > "$WORK/conj.clj" <<'EOF'
(defrecord R [x y])
(assert (= (assoc (->R 1 2) :z 9) (conj (->R 1 2) [:z 9])))   ; [k v] pair
(assert (= (assoc (->R 1 2) :x 100) (conj (->R 1 2) [:x 100]))) ; declared key
(assert (= (assoc (->R 1 2) :z 9) (conj (->R 1 2) (first {:z 9})))) ; map-entry
(assert (record? (conj (->R 1 2) [:z 9])))
(assert (= (assoc (->R 1 2) :z 9 :w 8) (conj (->R 1 2) {:z 9 :w 8}))) ; map → merge
(assert (= (assoc (->R 1 2) :z 9 :w 8) (into (->R 1 2) {:z 9 :w 8}))) ; into rides conj
(assert (= (->R 1 2) (conj (->R 1 2) nil)))                    ; conj nil → unchanged
(println "OK record-extmap-conj")
EOF
got="$("$BIN" "$WORK/conj.clj" 2>&1 | grep '^OK' || true)"
[[ "$got" == "OK record-extmap-conj" ]] || fail "conj: got '$("$BIN" "$WORK/conj.clj" 2>&1 | tail -4)'"
echo "PASS record_extmap_conj_into"

echo "ALL phase9_record_extmap PASS"
