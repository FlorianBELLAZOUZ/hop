;*=====================================================================*/
;*    serrano/prgm/project/hop/3.2.x/js2scheme/hintnum.scm             */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Tue May  1 16:06:44 2018                          */
;*    Last change :  Tue May  1 17:37:35 2018 (serrano)                */
;*    Copyright   :  2018 Manuel Serrano                               */
;*    -------------------------------------------------------------    */
;*    hint typing of numerical values.                                 */
;*    -------------------------------------------------------------    */
;*    This optimization consists in propagating expressions and        */
;*    declarations hints that will be used by the code generator.      */
;*    -------------------------------------------------------------    */
;*    Two top-down hints are propagated on unary and binary            */
;*    operations.                                                      */
;*                                                                     */
;*      1- if only one argument of binary expression is typed/hinted,  */
;*         add its type/hint as a hint of the second argument.         */
;*      2- if the result is typed/hinted propagate that hint to the    */
;*         arguments.                                                  */
;*                                                                     */
;*    This propagation iterates until the fix point is reached.        */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_hintnum

   (include "ast.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_compile
	   __js2scheme_stage)

   (export j2s-hintnum-stage))

;*---------------------------------------------------------------------*/
;*    j2s-hintnum-stage ...                                            */
;*---------------------------------------------------------------------*/
(define j2s-hintnum-stage
   (instantiate::J2SStageProc
      (name "hintnum")
      (comment "Numerical hint typing")
      (proc j2s-hintnum)))

;*---------------------------------------------------------------------*/
;*    j2s-hintnum ...                                                  */
;*---------------------------------------------------------------------*/
(define (j2s-hintnum this conf)
   
   (define j2s-verbose (config-get conf :verbose 0))
   
   (when (isa? this J2SProgram)
      (when (config-get conf :optim-hintnum #f)
	 (when (>=fx j2s-verbose 4) (display " " (current-error-port)))
	 (let ((fix (make-cell #t)))
	    (let loop ((i 1))
	       (when (>=fx j2s-verbose 4)
		  (fprintf (current-error-port) "~a." i)
		  (flush-output-port (current-error-port)))
	       (cell-set! fix #t)
	       (hintnum this fix)
	       (unless (cell-ref fix)
		  (loop (+fx i 1)))))))
   this)

;*---------------------------------------------------------------------*/
;*    expr-hint ...                                                    */
;*---------------------------------------------------------------------*/
(define (expr-hint::pair-nil this::J2SExpr)
   (with-access::J2SExpr this (type hint)
      (cond
	 ((not (memq type '(number any))) (list (cons type 100)))
	 ((pair? hint) hint)
	 (else '()))))

;*---------------------------------------------------------------------*/
;*    add-expr-hint! ...                                               */
;*---------------------------------------------------------------------*/
(define (add-expr-hint! this::J2SExpr newhint fix)
   (when (pair? newhint)
      (with-access::J2SExpr this (hint)
	 (cond
	    ((null? hint)
	     (cell-set! fix #f)
	     (set! hint newhint))
	    ((not (every (lambda (h) (pair? (assq (car h) hint))) newhint))
	     (cell-set! fix #f)
	     (for-each (lambda (h)
			  (let ((c (assq (car h) hint)))
			     (if (pair? c)
				 (when (<fx (cdr c) (cdr h))
				    (cell-set! fix #f)
				    (set-cdr! c (cdr h)))
				 (begin
				    (cell-set! fix #f)
				    (set! hint (cons h hint))))))
		newhint))))))

;*---------------------------------------------------------------------*/
;*    union-hint! ...                                                  */
;*---------------------------------------------------------------------*/
(define (union-hint! x y)
   (for-each (lambda (x)
		(let ((c (assq (car x) y)))
		   (if (pair? c)
		       (set-cdr! c (max (cdr x) (cdr c)))
		       (set! y (cons x y)))))
      x)
   y)

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SNode ...                                            */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SNode fix::cell)
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    hintnum-binary ...                                               */
;*---------------------------------------------------------------------*/
(define (hintnum-binary this op lhs rhs fix)
   (case op
      ((+ - * / %)
       (when (memq (j2s-type lhs) '(any number))
	  (let ((hint (union-hint! (expr-hint this) (expr-hint rhs))))
	     (add-expr-hint! lhs hint fix)))
       (when (memq (j2s-type rhs) '(any number))
	  (let ((hint (union-hint! (expr-hint this) (expr-hint lhs))))
	     (add-expr-hint! rhs hint fix))))
      ((< > <= >= == === != !==)
       (when (memq (j2s-type lhs) '(any number))
	  (let ((hint (expr-hint rhs)))
	     (add-expr-hint! lhs hint fix)))
       (when (memq (j2s-type rhs) '(any number))
	  (let ((hint (expr-hint lhs)))
	     (add-expr-hint! rhs hint fix))))))

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SBinary ...                                          */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SBinary fix::cell)
   (call-default-walker)
   (with-access::J2SBinary this (lhs rhs op)
      (hintnum-binary this op lhs rhs fix)))

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SUnary ...                                           */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SUnary fix::cell)
   (call-default-walker)
   (with-access::J2SUnary this (expr)
      (when (memq (j2s-type expr) '(any number))
	 (add-expr-hint! expr (expr-hint this) fix))))

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SAssigOp ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SAssigOp fix::cell)
   (with-access::J2SAssigOp this (op lhs rhs)
      (call-default-walker)
      (hintnum-binary this op lhs rhs fix)))

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SPostfix ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SPostfix fix::cell)
   (with-access::J2SPostfix this (op lhs rhs)
      (call-default-walker)
      (hintnum-binary this op lhs rhs fix)))

;*---------------------------------------------------------------------*/
;*    hintnum ::J2SPrefix ...                                          */
;*---------------------------------------------------------------------*/
(define-walk-method (hintnum this::J2SPrefix fix::cell)
   (with-access::J2SPrefix this (op lhs rhs)
      (call-default-walker)
      (hintnum-binary this op lhs rhs fix)))
	 