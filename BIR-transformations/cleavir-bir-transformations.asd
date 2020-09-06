(cl:in-package #:asdf-user)

(defsystem :cleavir-bir-transformations
  :depends-on (:cleavir-bir)
  :components
  ((:file "packages")
   (:file "function-dag" :depends-on ("packages"))
   (:file "process-captured-variables"
    :depends-on ("function-dag" "packages"))))
