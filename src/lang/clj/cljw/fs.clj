;; cljw.fs — handy filesystem ops, require-able under the cljw.* namespace
;; (ADR-0126 Cycle 7, user-requested). A babashka.fs-style thin layer over the
;; java.io.File host type + clojure.java.io (the neutral impl lives in
;; runtime/file_io.zig + runtime/java/io/File.zig per F-009 — this never forks
;; it). Predicates/ops take a path String or a java.io.File. FS-jail aware (the
;; underlying File methods route through the deploy jail).
(ns cljw.fs)

(defn file
  "A java.io.File from one or more path segments (parent + children)."
  [& args]
  (apply clojure.java.io/file args))

(defn exists?      [p] (.exists (clojure.java.io/file p)))
(defn directory?   [p] (.isDirectory (clojure.java.io/file p)))
(defn regular-file? [p] (.isFile (clojure.java.io/file p)))
(defn absolute?    [p] (.isAbsolute (clojure.java.io/file p)))
(defn file-name    [p] (.getName (clojure.java.io/file p)))
(defn parent       [p] (.getParentFile (clojure.java.io/file p)))
(defn path         [p] (.getPath (clojure.java.io/file p)))
(defn size         [p] (.length (clojure.java.io/file p)))
(defn list-dir     [p] (.list (clojure.java.io/file p)))
(defn delete       [p] (.delete (clojure.java.io/file p)))
(defn create-dir   [p] (.mkdir (clojure.java.io/file p)))
(defn create-dirs  [p] (.mkdirs (clojure.java.io/file p)))
