;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/unthis.scm                */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Thu Dec 21 09:27:29 2017                          */
;*    Last change :  Mon Dec 30 09:56:14 2019 (serrano)                */
;*    Copyright   :  2017-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    This optimization removes the THIS argument of functions that    */
;*    don't need it, i.e., that do not escape and that do not use it.  */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_unthis

   (include "ast.sch"
	    "usage.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_alpha)

   (export j2s-unthis-stage))

;*---------------------------------------------------------------------*/
;*    j2s-unthis-stage                                                 */
;*---------------------------------------------------------------------*/
(define j2s-unthis-stage
   (instantiate::J2SStageProc
      (name "unthis")
      (comment "this elimination")
      (proc j2s-unthis)
      (optional 2)))

;*---------------------------------------------------------------------*/
;*    j2s-unthis ...                                                   */
;*---------------------------------------------------------------------*/
(define (j2s-unthis this args)
   (when (isa? this J2SProgram)
      (with-access::J2SProgram this (nodes decls)
	 (for-each (lambda (n) (unthis n)) decls)
	 (for-each (lambda (n) (unthis n)) nodes)))
   this)

;*---------------------------------------------------------------------*/
;*    unthis ::J2SNode ...                                             */
;*---------------------------------------------------------------------*/
(define-walk-method (unthis this::J2SNode)
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    unthis ::J2SDeclInit ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (unthis this::J2SDeclInit)
   (call-default-walker)
   (with-access::J2SDeclInit this (val)
      (when (and (decl-ronly? this) (isa? val J2SFun) (not (isa? val J2SSvc)))
	 (with-access::J2SFun val (generator idthis thisp)
	    (when (and (not generator) (decl-usage-strict? this '(init call)))
	       (when (isa? thisp J2SDecl)
		  (with-access::J2SDecl thisp (usecnt)
		     (when (=fx usecnt 0)
			(set! idthis #f)
			(set! thisp #f)))))))))
		  
		  
