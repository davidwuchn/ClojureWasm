(ns verify
  (:require [hiccup.core :as h]
            [hiccup.page :as page]))
;; hiccup renders a data-literal tree to an HTML string. Exercise the core
;; macro (compile-time literal path), attribute maps, seq children, and the
;; page helper so the util/compiler/page namespaces all load + run.
(defn -main [& _]
  (assert (= "<p>hi</p>" (h/html [:p "hi"])))
  (assert (= "<a href=\"/x\">go</a>" (h/html [:a {:href "/x"} "go"])))
  (assert (= "<ul><li>1</li><li>2</li></ul>"
             (h/html [:ul (for [i [1 2]] [:li (str i)])])))
  (assert (= "<div class=\"a\" id=\"b\"></div>" (h/html [:div#b.a])))
  (assert (.startsWith (page/html5 [:body "x"]) "<!DOCTYPE html>"))
  (println "OK hiccup — html macro, attrs, seq children, css shorthand, html5 page"))
