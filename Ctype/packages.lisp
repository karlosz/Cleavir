(defpackage #:cleavir-ctype
  (:use #:common-lisp)
  (:shadow #:subtypep #:rest
           #:upgraded-array-element-type
           #:upgraded-complex-part-type
           #:cons #:array #:complex #:member
           #:satisfies #:function #:values
           #:funcall #:apply)
  (:export #:subtypep
           #:upgraded-array-element-type
           #:upgraded-complex-part-type)
  (:export #:conjoin/2 #:disjoin/2 #:negate #:subtract
           #:top #:bottom #:top-p #:bottom-p
           #:conjoin #:disjoin)
  (:export #:cons #:array #:complex #:range
           #:member #:satisfies #:function #:values
           #:coerce-to-values)
  (:export #:values-required #:values-optional #:values-rest)
  (:export #:apply #:funcall))
