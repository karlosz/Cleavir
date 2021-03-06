(in-package #:cleavir-bir)

(defvar *ids*)
(defvar *name-ids*)

(defvar *in-disassembly* nil)
(defmacro with-disassembly ((&key override) &body body)
  (let ((bodyf (gensym "BODY")))
    `(flet ((,bodyf () ,@body))
       (if (or ,override (not *in-disassembly*))
           (let ((*in-disassembly* t)
                 (*name-ids* (make-hash-table :test #'equal))
                 (*ids* (make-hash-table :test #'eq)))
             (,bodyf))
           (,bodyf)))))

;; Prevents collisions by adding -## at the end.
(defun name-id (name)
  (multiple-value-bind (value presentp) (gethash name *name-ids*)
    (cond ((null name)
           (setf (gethash name *name-ids*) (if presentp (1+ value) 1))
           (make-symbol (write-to-string (if presentp value 0))))
          (presentp
           (setf (gethash name *name-ids*) (1+ value))
           (make-symbol (concatenate 'string
                                     (write-to-string name :escape nil)
                                     "-"
                                     (write-to-string value :escape nil))))
          (t
           (setf (gethash name *name-ids*) 0)
           (make-symbol (write-to-string name :escape nil))))))

(defgeneric disassemble-datum (datum))
(defmethod disassemble-datum ((value constant)) `',(constant-value value))
(defmethod disassemble-datum ((value datum))
  (or (gethash value *ids*)
      (setf (gethash value *ids*)
            (name-id (name value)))))
(defmethod disassemble-datum ((datum catch))
  (name-id (or (name datum) 'unnamed-tag)))

(defun label (instruction)
  (class-name (class-of instruction)))

(defgeneric disassemble-instruction-extra (instruction)
  (:method-combination append)
  (:method append ((instruction instruction)) ()))

(defun disassemble-instruction (instruction)
  (let ((dis `(,(label instruction)
               ,@(mapcar #'disassemble-datum (inputs instruction))
               ,@(disassemble-instruction-extra instruction))))
    `(:= (,@(mapcar (lambda (out)
                      `(,(disassemble-datum out)
                        ,@(when (typep out 'linear-datum)
                            `(,(ctype out)))))
                    (outputs instruction)))
         ,dis)))

(defun iblock-id (iblock)
  (or (gethash iblock *ids*)
      (setf (gethash iblock *ids*)
            (name-id (name iblock)))))

(defmethod disassemble-instruction-extra append ((inst primop))
  (list (cleavir-primop-info:name (info inst))))

(defmethod disassemble-instruction-extra append ((inst terminator))
  (let ((n (mapcar #'iblock-id (next inst))))
    (if (null n)
        nil
        (list (mapcar #'iblock-id (next inst))))))

(defmethod disassemble-instruction-extra append ((inst enclose))
  (list (disassemble-datum (code inst))))

(defmethod disassemble-instruction-extra append ((inst catch))
  (list (disassemble-datum inst)))

(defmethod disassemble-instruction-extra append ((inst unwind))
  (list (disassemble-datum (catch inst))
        (iblock-id (destination inst))))

(defmethod disassemble-instruction-extra append ((inst load-time-value))
  (list (form inst) (read-only-p inst)))

(defmethod disassemble-instruction-extra append ((inst typeq-test))
  (list (test-ctype inst)))

(defmethod disassemble-instruction-extra append ((inst thei))
  (list (asserted-type inst) (type-check-function inst)))

(defun disassemble-iblock (iblock)
  (check-type iblock iblock)
  (with-disassembly ()
    (let ((insts nil))
      (do-iblock-instructions (i (start iblock))
        (push (disassemble-instruction i) insts))
      (list* (list* (iblock-id iblock)
                    (mapcar #'disassemble-datum (inputs iblock)))
             (dynamic-environment iblock)
             (cleavir-set:mapset 'list #'iblock-id (entrances iblock))
             (nreverse insts)))))

(defun disassemble-lambda-list (ll)
  (loop for item in ll
        collect (cond ((member item lambda-list-keywords) item)
                      ((typep item 'argument)
                       (disassemble-datum item))
                      ((= (length item) 3)
                       (list (first item)
                             (disassemble-datum (second item))
                             (disassemble-datum (third item))))
                      (t (mapcar #'disassemble-datum item)))))

(defun disassemble-function (function)
  (check-type function function)
  (with-disassembly ()
    (let ((iblocks nil))
      ;; sort blocks in forward flow order.
      (do-iblocks (iblock function :backward)
        (push (disassemble-iblock iblock) iblocks))
    (list* (list (disassemble-datum function) (iblock-id (start function))
                 (disassemble-lambda-list (lambda-list function))
                 (cleavir-set:mapset 'list #'disassemble-datum
                                     (environment function)))
           iblocks))))

(defun disassemble (module)
  (check-type module module)
  (with-disassembly ()
    (cons (constants module)
          (cleavir-set:mapset 'list #'disassemble-function
                              (functions module)))))

(defun print-iblock-disasm (iblock-disasm &key (show-dynenv t))
  (destructuring-bind ((label . args) dynenv entrances &rest insts)
      iblock-disasm
    (format t "~&  iblock ~a ~:a:" label args)
    (when show-dynenv
      (format t "~&   dynenv = ~a" dynenv))
    (when entrances
      (format t "~&   entrances = ~(~:a~)" entrances))
    (dolist (inst insts)
      (destructuring-bind (_ outs . rest) inst
        (declare (cl:ignore _))
        (format t "~&     ")
        (format t "~{~(~a~)~}" rest)
        (when outs
          (format t " -> "))
        (format t "~{~a~^, ~}" (mapcar #'first outs))
        (let* ((type-specs (mapcar #'cdr outs))
               (types (mapcar #'first type-specs)))
          (unless (or (every (lambda (ctype) (cleavir-ctype:top-p ctype nil)) types)
                      (every (lambda (type-spec) (eq type-spec nil)) type-specs))
            (format t "~45T; ")
            (format t "~{ctype: ~a~^, ~}" types)))))))

(defun print-function-disasm (function-disasm &key (show-dynenv t))
  (destructuring-bind ((name start args env) . iblocks)
      function-disasm
    (format t "~&function ~a ~:a ~&     with environment ~(~a~) ~&     with start iblock ~a"
            name args env start)
    (dolist (iblock iblocks)
      (print-iblock-disasm iblock :show-dynenv show-dynenv))))

(defun print-disasm (disasm &key (show-dynenv t))
  (format t "~&-------module-------")
  (destructuring-bind (constants . funs) disasm
    (format t "~&constants: ~a" constants)
    (dolist (fun funs)
      (print-function-disasm fun :show-dynenv show-dynenv))))
