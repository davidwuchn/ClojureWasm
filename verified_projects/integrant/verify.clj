(ns verify
  (:require [integrant.core :as ig]))
;; integrant requires QUALIFIED keys. :app/db depends on :app/cfg via an
;; ig/ref, so init walks the dep graph and starts :app/cfg first, injecting
;; its value where the ref sits.
(defmethod ig/init-key :app/cfg [_ v] (assoc v :loaded true))
(defmethod ig/init-key :app/db  [_ {:keys [cfg]}] [:conn (:url cfg)])
(defmethod ig/halt-key! :app/db [_ _])
(defn -main [& _]
  (let [config {:app/cfg {:url "u"}
                :app/db  {:cfg (ig/ref :app/cfg)}}
        sys (ig/init config)]
    (assert (= {:url "u" :loaded true} (:app/cfg sys)))
    (assert (= [:conn "u"] (:app/db sys)))
    (ig/halt! sys))
  (println "OK integrant — init/halt with ref dependency ordering"))
