(in-package #:cleavir-bir-transformations)

;;;; This is a BIR post-pass which takes THEI and generates the type
;;;; check by inlining or local calling the type check function stored
;;;; in the instruction. If there is a manifest type conflict, we warn
;;;; about it here.

;;;; This pass should run before function environments are determined,
;;;; since it may inline functions.

;;; Warn about a compile time type conflict.
(defun maybe-warn-type-conflict (thei)
  (let ((input (first (cleavir-bir:inputs thei))))
    (when (cleavir-ctype:disjointp (cleavir-bir:asserted-type thei)
                                   (cleavir-bir:ctype input)
                                   nil)
      (warn 'cleavir-bir:type-conflict
            :datum input
            :asserted-type (cleavir-bir:asserted-type thei)
            :derived-type (cleavir-bir:ctype input)
            :asserted-by thei
            :origin (cleavir-bir:origin thei)))))

(defun generate-type-check (thei)
  (let* ((input (first (cleavir-bir:inputs thei)))
         (type-check-function (cleavir-bir:type-check-function thei)))
    (unless (symbolp type-check-function)
      (let ((rtype (cleavir-bir:rtype thei)))
        (case rtype
          (:object
           (change-class thei 'cleavir-bir:local-call
                         :inputs (list type-check-function input))
           (let ((mtf (make-instance 'cleavir-bir:multiple-to-fixed
                                     :outputs (list (make-instance 'cleavir-bir:output
                                                                   :rtype :object)))))
             (cleavir-bir:insert-instruction-after mtf thei)
             (cleavir-bir:replace-uses (first (cleavir-bir:outputs mtf)) thei)
             (setf (cleavir-bir:inputs mtf) (list thei))
             (post-find-local-calls type-check-function)))
          (:multiple-values
           (change-class thei 'cleavir-bir:mv-local-call
                         :inputs (list type-check-function input))))))))

(defun generate-type-checks (function)
  (let ((theis '()))
    (cleavir-bir:do-iblocks (iblock function)
      (cleavir-bir:do-iblock-instructions (instruction (cleavir-bir:start iblock))
        (when (typep instruction 'cleavir-bir:thei)
          (push instruction theis))))
    ;; We first warn about type conflicts in case we lose derived
    ;; types when generating type checks.
    (mapc #'maybe-warn-type-conflict theis)
    (mapc #'generate-type-check theis)))

(defun module-generate-type-checks (module)
  (cleavir-bir:map-functions #'generate-type-checks module))
