;*=====================================================================*/
;*    serrano/prgm/project/hop/3.2.x/js2scheme/any.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Dec 22 19:47:45 2017                          */
;*    Last change :  Wed Oct 17 08:39:37 2018 (serrano)                */
;*    Copyright   :  2017-20 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    An optional stage used in debug mode to replace UNKNOWN type     */
;*    occurrences with ANY.                                            */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_any

   (include "ast.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_compile
	   __js2scheme_stage)

   (export j2s-any-stage))

;*---------------------------------------------------------------------*/
;*    j2s-any-stage                                                    */
;*---------------------------------------------------------------------*/
(define j2s-any-stage
   (instantiate::J2SStageProc
      (name "any")
      (comment "Variable pre-initialization")
      (proc j2s-any)))

;*---------------------------------------------------------------------*/
;*    j2s-any ...                                                      */
;*---------------------------------------------------------------------*/
(define (j2s-any this args)
   (when (isa? this J2SProgram)
      (any-types this))
   this)

;*---------------------------------------------------------------------*/
;*    map-type ...                                                     */
;*---------------------------------------------------------------------*/
(define (map-type type)
   (if (eq? type 'unknown) 'any type))

;*---------------------------------------------------------------------*/
;*    any-types  ...                                                   */
;*    -------------------------------------------------------------    */
;*    Map compiler types to actual target types (i.e., maps uint29     */
;*    to uint32, length to uint32, intege to bint, etc...).            */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SNode)
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SString ...                                        */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SString)
   (with-access::J2SExpr this (type)
      (set! type 'string)))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SBool ...                                          */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SBool)
   (with-access::J2SExpr this (type)
      (set! type 'bool)))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SArray ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SArray)
   (with-access::J2SArray this (type exprs)
      (for-each any-types exprs)
      (set! type 'array)))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SExpr ...                                          */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SExpr)
   (with-access::J2SExpr this (type)
      (set! type (map-type type)))
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SFun ...                                           */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SFun)
   (with-access::J2SFun this (rtype thisp argumentsp decl)
      (when (isa? thisp J2SDecl) (any-types thisp))
      (when (isa? argumentsp J2SDecl) (any-types argumentsp))
      (when (isa? decl J2SDecl)
	 (with-access::J2SDecl decl (vtype)
	    (set! vtype (map-type vtype))))
      (set! rtype (map-type rtype)))
   (call-default-walker)
   (call-next-method))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SHopRef ...                                        */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SHopRef)
   (with-access::J2SHopRef this (type)
      (set! type (map-type type)))
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SGlobalRef ...                                     */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SGlobalRef)
   (with-access::J2SGlobalRef this (type decl)
      (with-access::J2SDecl decl (vtype)
	 (set! vtype (map-type vtype)))
      (set! type (map-type type)))
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SDecl ...                                          */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SDecl)
   (with-access::J2SDecl this (vtype id)
      (set! vtype (map-type vtype))))
	 
;*---------------------------------------------------------------------*/
;*    any-types ::J2SDeclInit ...                                      */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SDeclInit)
   (call-next-method)
   (with-access::J2SDeclInit this (val id loc)
      (any-types val)))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SBinary ...                                        */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SBinary)
   (with-access::J2SBinary this (op type)
      (if (memq type '(index integer number))
	  (case op
	     ((>> << BIT_OT ^ &) (set! type 'int32))
	     ((>>>) (set! type 'uint32))
	     (else (set! type (map-type type))))
	  (set! type (map-type type))))
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SUnary ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SUnary)
   (with-access::J2SUnary this (op type)
      (if (and (eq? op '~) (memq type '(integer index number)))
	  (set! type 'int32)
	  (set! type (map-type type))))
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    any-types ::J2SCatch ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SCatch)
   (with-access::J2SCatch this (param)
      (any-types param)
      (call-default-walker)))
   
;*---------------------------------------------------------------------*/
;*    any-types ::J2SPostfix ...                                       */
;*---------------------------------------------------------------------*/
(define-walk-method (any-types this::J2SPostfix)
   (with-access::J2SPostfix this (type)
      (set! type 'number)
      (call-default-walker)))
