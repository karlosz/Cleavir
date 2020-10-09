(in-package #:cleavir-bir-transformations)

(defun owners (&rest use-sets)
  (let ((owners (cleavir-set:empty-set)))
    (dolist (use-set use-sets)
      (cleavir-set:doset (use use-set)
        (cleavir-set:nadjoinf owners (cleavir-bir:function use))))
    owners))

;;; Add VARIABLE onto the environment of ACCESS-FUNCTION and do so
;;; recursively.
(defun close-over-variable (function access-function variable)
  (unless (eq function access-function)
    (cleavir-set:nadjoinf (cleavir-bir:environment access-function) variable)
    (cleavir-set:doset (use (owners (cleavir-bir:encloses access-function)
                                    (cleavir-bir:local-calls access-function)))
      (close-over-variable function (cleavir-bir:function use) variable))))

;;; Fill in the environments of every function.
(defun process-captured-variables (ir)
  (cleavir-set:doset (function (cleavir-bir:functions (cleavir-bir:module ir)) (values))
    (cleavir-set:doset (variable (cleavir-bir:variables function))
      (cleavir-set:doset (access-function (owners (cleavir-bir:readers variable)
                                                  (cleavir-bir:writers variable)))
        (close-over-variable function access-function variable)))))

;; Find all calls to a function and mark them as local calls.

;; FIXME: Right now, this runs on functions which are explicitly not
;; closures, so this needs to happen after p-c-v. This is rather
;; suboptimal, since the true power of local calls lies in eliding
;; heap allocated closures. Otherwise we can run this straight away
;; and have p-c-v do lambda lifting on local calls.
(defun find-local-calls (function)
  (cleavir-set:doset (enclose (cleavir-bir:encloses function))
    (let ((use (cleavir-bir:use enclose))
          (external-reference-p nil))
      (when (cleavir-set:empty-set-p (cleavir-bir:environment function))
        (typecase use
          (cleavir-bir:call
           (change-class use 'cleavir-bir::local-call)
           (cleavir-bir:replace-computation enclose function))
          (cleavir-bir:writevar
           (let ((variable (first (cleavir-bir:outputs use))))
             (when (cleavir-bir:immutablep variable)
               (cleavir-set:doset (reader (cleavir-bir:readers variable))
                 (let ((use (cleavir-bir:use reader)))
                   (typecase use
                     (cleavir-bir:call
                      (when (or (eq use (cleavir-bir:callee use))
                                (not (member reader (rest (cleavir-bir:inputs use)))))
                        (change-class use 'cleavir-bir::local-call)
                        (cleavir-bir:replace-computation reader function)))
                     (t
                      (setq external-reference-p t)))))))
           (unless external-reference-p
             (cleavir-bir:delete-instruction use))))
        (unless external-reference-p
          (cleavir-bir:delete-computation enclose))))))

(defun local-call-analyze-module (module)
  (cleavir-set:mapset nil #'find-local-calls (cleavir-bir:functions module)))
