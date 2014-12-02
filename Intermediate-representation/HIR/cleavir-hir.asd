(cl:in-package #:common-lisp-user)

(asdf:defsystem :cleavir-hir
  :depends-on (:cleavir-ir)
  :serial t
  :components
  ((:file "data")
   (:file "box-unbox-mixins")
   (:file "side-effect-mixins")
   (:file "general-purpose-instructions")
   (:file "fixnum")
   (:file "integer")
   (:file "float")
   (:file "cons")
   (:file "standard-object")
   (:file "array")
   (:file "multiple-values")
   (:file "graphviz-drawing")))
