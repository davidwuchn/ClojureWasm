;; e2e fixture for cljw.http.server (ADR-0098): a tiny Ring router.
;; GET → "GET <uri>"; POST → 201 "created". Binds 0.0.0.0:8157 (blocking).
(cljw.http.server/run-server
  (fn [req]
    (if (= (:request-method req) :post)
      {:status 201 :body "created"}
      {:status 200 :body (str "GET " (:uri req))}))
  {:port 8157})
