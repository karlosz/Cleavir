(cl:in-package #:common-lisp-user)

(defpackage #:cleavir-primop
  (:use)
  (:export
   #:eq #:typeq #:typew #:the-typew #:case
   #:car #:cdr #:rplaca #:rplacd
   #:fixnum-arithmetic
   #:fixnum-add
   #:fixnum-sub
   #:fixnum-less
   #:fixnum-not-greater
   #:fixnum-greater
   #:fixnum-not-less
   #:fixnum-equal
   ;; Each of these operations takes a type argument in addition to
   ;; the normal argument(s) of the corresponding Common Lisp
   ;; function.  That type argument is the first one, and it is not
   ;; evaluated.
   #:float-add
   #:float-sub
   #:float-mul
   #:float-div
   #:float-less
   #:float-not-greater
   #:float-greater
   #:float-not-less
   #:float-equal
   #:float-sin
   #:float-cos
   #:float-sqrt
   #:coerce
   #:slot-read #:slot-write
   #:funcallable-slot-read #:funcallable-slot-write
   #:aref #:aset
   #:call-with-variable-bound
   #:let-uninitialized
   #:the
   #:funcall
   #:multiple-value-call
   #:multiple-value-extract
   #:multiple-value-setq
   #:values
   #:unreachable
   #:ast
   #:cst-to-ast))

(defpackage #:cleavir-primop-info
  (:use #:cl)
  (:export #:info #:defprimop
           #:name #:in-rtypes #:out-rtypes #:attributes))
