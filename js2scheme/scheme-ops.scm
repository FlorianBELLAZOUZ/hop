;*=====================================================================*/
;*    serrano/prgm/project/hop/3.2.x/js2scheme/scheme-ops.scm          */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Mon Aug 21 07:21:19 2017                          */
;*    Last change :  Thu Jan 24 06:57:26 2019 (serrano)                */
;*    Copyright   :  2017-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Unary and binary Scheme code generation                          */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_scheme-ops

   (include "ast.sch")

   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_js
	   __js2scheme_stmtassign
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_scheme
	   __js2scheme_scheme-cast
	   __js2scheme_scheme-utils
	   __js2scheme_scheme-test)

   (export (j2s-in? loc id obj)
	   (j2s-scheme-binary-as ::J2SBinary mode return conf type)
	   (j2s-scheme-unary-as ::J2SUnary mode return conf type)
	   (js-binop2 loc op::symbol type lhs::J2SNode rhs::J2SNode
	      mode return conf)))

;*---------------------------------------------------------------------*/
;*    j2s-scheme ::J2SUnary ...                                        */
;*---------------------------------------------------------------------*/
(define-method (j2s-scheme this::J2SUnary mode return conf)
   (with-access::J2SUnary this (loc op type expr)
      (js-unop loc op type expr mode return conf)))

;*---------------------------------------------------------------------*/
;*    j2s-scheme-unary-as ...                                          */
;*---------------------------------------------------------------------*/
(define (j2s-scheme-unary-as this::J2SUnary mode return conf type)
   (with-access::J2SUnary this (loc expr op)
      (cond
	 ((and (eq? op '-) (memq type '(int32 uint32 int53 integer number)))
	  (js-unop loc op type expr mode return conf))
	 ((and (eq? op '!) (eq? type 'bool))
	  (js-unop loc op type expr mode return conf))
	 ((and (eq? op '~) (eq? type 'int32))
	  (js-unop loc op type expr mode return conf))
	 (else
	  #f))))

;*---------------------------------------------------------------------*/
;*    j2s-scheme ::J2SBinary ...                                       */
;*---------------------------------------------------------------------*/
(define-method (j2s-scheme this::J2SBinary mode return conf)
   (with-access::J2SBinary this (loc op lhs rhs type)
      (epairify-deep loc
	 (js-binop2 loc op type lhs rhs mode return conf))))

;*---------------------------------------------------------------------*/
;*    j2s-scheme-binary-as ...                                         */
;*---------------------------------------------------------------------*/
(define (j2s-scheme-binary-as this::J2SBinary mode return conf type)
   (with-access::J2SBinary this (loc op lhs rhs)
      (cond
	 ((and (eq? op '+)
	       (memq type '(int32 uint32 int53 integer number string)))
	  (epairify-deep loc
	     (js-binop2 loc op type lhs rhs mode return conf)))
	 ((and (memq op '(* - / >> << >>> & BIT_OR ^))
	       (memq type '(int32 uint32)))
	  (epairify-deep loc
	     (js-binop2 loc op type lhs rhs mode return conf)))
	 (else
	  #f))))

;*---------------------------------------------------------------------*/
;*    scm-fixnum? ...                                                  */
;*---------------------------------------------------------------------*/
(define (scm-fixnum? sexp node::J2SNode)
   (cond
      ((fixnum? sexp) #t)
      ((type-int30? (j2s-vtype node)) #t)
      ((symbol? sexp) `(fixnum? ,sexp))
      (else #f)))

;*---------------------------------------------------------------------*/
;*    scm-and ...                                                      */
;*---------------------------------------------------------------------*/
(define (scm-and left right)

   (define (fixnum-test e)
      (match-case e
	 ((fixnum? ?e) e)
	 (else #f)))

   (cond
      ((eq? left #t)
       (if (eq? right #t) #t right))
      ((eq? right #t)
       left)
      ((and (fixnum-test left) (fixnum-test right))
       `(and (fixnum? ,(fixnum-test left)) (fixnum? ,(fixnum-test right))))
      ((and left right)
       `(and ,left ,right))
      (else #f)))

;*---------------------------------------------------------------------*/
;*    scm-if ...                                                       */
;*---------------------------------------------------------------------*/
(define (scm-if test then otherwise)
   (cond
      ((eq? test #t) then)
      ((> (bigloo-debug) 0) otherwise)
      (else `(if ,test ,then ,otherwise))))

;*---------------------------------------------------------------------*/
;*    js-unop ...                                                      */
;*---------------------------------------------------------------------*/
(define (js-unop loc op type expr mode return conf)
   
   (define (err id)
      (match-case loc
	 ((at ?fname ?loc)
	  `(with-access::JsGlobalObject %this (js-syntax-error)
	      (js-raise
		 (js-new %this js-syntax-error
		    ,(j2s-jsstring
			(format "Delete of an unqualified identifier in strict mode: \"~a\"" id)
			loc)
		    ,fname ,loc))))
	 (else
	  `(with-access::JsGlobalObject %this (js-syntax-error)
	      (js-raise
		 (js-new %this js-syntax-error
		    ,(j2s-jsstring
			(format "Delete of an unqualified identifier in strict mode: \"~a\"" id)
			loc)))))))
   
   (define (delete->scheme expr)
      ;; http://www.ecma-international.org/ecma-262/5.1/#sec-8.12.7
      (cond
	 ((isa? expr J2SWithRef)
	  (with-access::J2SWithRef expr (id withs expr loc)
	     (let loop ((withs withs))
		(if (null? withs)
		    `(begin ,(j2s-scheme expr mode return conf) #f)
		    `(if ,(j2s-in? loc `',id (car withs))
			 (js-delete! ,(j2s-scheme (car withs) mode return conf)
			    ',(j2s-scheme id mode return conf)
			    #f
			    %this)
			 ,(loop (cdr withs)))))))
	 ((isa? expr J2SAccess)
	  (with-access::J2SAccess expr (obj field)
	     `(js-delete! ,(j2s-scheme obj mode return conf)
		 ,(j2s-scheme field mode return conf)
		 ,(strict-mode? mode)
		 %this)))
	 ((isa? expr J2SUnresolvedRef)
	  (if (strict-mode? mode)
	      (with-access::J2SUnresolvedRef expr (id)
		 (err id))
	      (with-access::J2SUnresolvedRef expr (id)
		 `(js-delete! ,j2s-unresolved-del-workspace ',id #f %this))))
	 ((and (isa? expr J2SRef) (not (isa? expr J2SThis)))
	  (if (strict-mode? mode)
	      (with-access::J2SRef expr (decl)
		 (with-access::J2SDecl decl (id)
		    (err id)))
	      '(begin #f)))
	 ((isa? expr J2SParen)
	  (with-access::J2SParen expr (expr)
	     (delete->scheme expr)))
	 (else
	  `(begin ,(j2s-scheme expr mode return conf) #t))))

   (define (typeof->scheme expr)
      (let ((ty (j2s-type expr)))
	 (cond
	    ((memq ty '(int30 int32 uint32 fixnum integer real number))
	     `(js-ascii->jsstring "number"))
	    ((eq? ty 'string)
	     `(js-ascii->jsstring "string"))
	    ((isa? expr J2SUnresolvedRef)
	     ;; http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.3
	     (with-access::J2SUnresolvedRef expr (id loc cache)
		`(js-typeof ,(j2s-unresolved id #f cache loc))))
	    ((isa? expr J2SParen)
	     (with-access::J2SParen expr (expr)
		(typeof->scheme expr)))
	    (else
	     `(js-typeof ,(j2s-scheme expr mode return conf))))))

   (define (bitnot loc expr)
      ;; optimize the pattern ~~expr that is sometime used to cast
      ;; an expression into a number
      (match-case expr
	 ((bit-nots32 ?expr) expr)
	 (else (epairify loc `(bit-nots32 ,expr)))))
   
   (case op
      ((!)
       (if (eq? type 'bool)
	   (let ((sexp (j2s-test-not expr mode return conf)))
	      (if (pair? sexp)
		  (epairify loc sexp)
		  sexp))
	   (epairify loc
	      `(if ,(j2s-test expr mode return conf) #f #t))))
      ((typeof)
       (epairify loc
	  (typeof->scheme expr)))
      ((void)
       (epairify loc
	  `(begin
	      ,(j2s-scheme expr mode return conf)
	      (js-undefined))))
      ((delete)
       (epairify loc
	  (delete->scheme expr)))
      ((+)
       ;; http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.6
       (let ((sexpr (j2s-scheme expr mode return conf))
	     (typ (j2s-type expr))
	     (vtyp (j2s-vtype expr)))
	  (cond
	     ((eqv? sexpr 0)
	      +0.0)
	     ((memq vtyp '(int32 uint32 int53 integer number))
	      sexpr)
	     ((memq typ '(int32 uint32 int53 integer number))
	      (j2s-cast sexpr expr vtyp typ conf))
	     (else
	      (epairify loc `(js-tonumber ,sexpr %this))))))
      ((-)
       ;; http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.7
       (let ((sexpr (j2s-scheme expr mode return conf))
	     (vtyp (j2s-vtype expr))
	     (typ (j2s-type expr)))
	  (case type
	     ((int32)
	      (cond
		 ((int32? sexpr)
		  (if (=s32 sexpr #s32:0) -0.0 (negs32 sexpr)))
		 ((eq? vtyp 'int32)
		  (epairify loc `(negs32 ,sexpr)))
		 ((eq? vtyp 'uint32)
		  (epairify loc `(negs32 ,(asint32 sexpr 'uint32))))
		 ((memq typ '(int32 uint32))
		  (epairify loc `(js-toint32 (negfx ,sexpr) %this)))
		 (else
		  (epairify loc `(js-toint32 (negjs ,sexpr %this) %this)))))
	     ((uint32)
	      (cond
		 ((eq? vtyp 'int32)
		  (epairify loc `(int32->uint32 (negs32 ,sexpr))))
		 ((memq type '(int32 uint32))
		  (epairify loc `(js-touint32 (negfx ,sexpr) %this)))
		 (else
		  (epairify loc `(js-touint32 (negjs ,sexpr %this) %this)))))
	     ((eqv? sexpr 0)
	      -0.0)
	     ((integer)
	      (if (fixnum? sexpr)
		  (negfx sexpr)
		  (epairify loc `(negfx ,sexpr))))
	     ((real)
	      (if (flonum? sexpr)
		  (negfl sexpr)
		  (epairify loc `(negfl ,sexpr))))
	     ((number)
	      (epairify loc
		 (case vtyp
		    ((int32)
		     `(if (=s32 ,sexpr #s32:0)
			  -0.0
			  ,(tonumber `(negs32 ,sexpr) vtyp conf)))
		    ((uint32)
		     (cond
			((m64? conf)
			 `(if (=u32 ,sexpr #u32:0)
			      -0.0
			      `(negfx ,(uint32->fixnum sexpr)) vtyp conf))
			((inrange-int32? expr)
			 `(if (=u32 ,sexpr #u32:0)
			      -0.0
			      ,(tonumber
				  `(negs32 ,(uint32->int32 sexpr)) vtyp conf)))
			(else
			 `(cond
			     ((=u32 ,sexpr #u32:0)
			      -0.0)
			     ((>u32 ,sexpr (fixnum->uint32 (maxvalfx)))
			      (negfl (uint32->flonum ,sexpr)))
			     (else
			      (negfx (uint32->fixxnum ,sexpr)))))))
		    ((int53)
		     `(if (=fx ,sexpr 0)
			  -0.0
			  (negfx ,sexpr)))
		    (else
		     `(negjs ,sexpr %this)))))
	     (else
	      (epairify loc `(negjs ,sexpr %this))))))
      ((~)
       ;; http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.8
       (if (eq? type 'int32)
	   (bitnot loc (j2s-scheme expr mode return conf))
	   `(bit-notjs ,(j2s-scheme expr mode return conf) %this)))
      (else
       (epairify loc
	  `(,op ,(j2s-scheme expr mode return conf))))))

;*---------------------------------------------------------------------*/
;*    js-binop2 ...                                                    */
;*---------------------------------------------------------------------*/
(define (js-binop2 loc op::symbol type lhs::J2SNode rhs::J2SNode
	   mode return conf)
   (case op
      ((+)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop loc op left lhs right rhs conf)))
	   (js-binop-add loc type lhs rhs mode return conf)))
      ((-)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop-arithmetic loc op left lhs right rhs conf)))
	   (js-arithmetic-addsub loc op type lhs rhs mode return conf)))
      ((*)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop-arithmetic loc op left lhs right rhs conf)))
	   (js-arithmetic-mul loc type lhs rhs mode return conf)))
      ((**)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop-arithmetic loc '** left lhs right rhs conf)))
	   (js-arithmetic-expt loc type lhs rhs mode return conf)))
      ((/)
       (js-arithmetic-div loc type lhs rhs mode return conf))
      ((remainderfx remainder)
       (with-tmp lhs rhs mode return conf 'any
	  (lambda (left right)
	     `(,op ,left ,right))))
      
      ((%)
       (js-arithmetic-% loc type lhs rhs mode return conf))
      ((eq?)
       (with-tmp lhs rhs mode return conf 'any
	  (lambda (left right)
	     `(eq? ,left ,right))))
      ((== === != !==)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop loc op left lhs right rhs conf)))
	   (js-equality loc op type lhs rhs mode return conf)))
      ((< <= > >=)
       (if (=fx (config-get conf :optim 0) 0)
	   (with-tmp lhs rhs mode return conf 'any
	      (lambda (left right)
		 (js-binop loc op left lhs right rhs conf)))
	   (js-cmp loc op lhs rhs mode return conf)))
      ((& ^ BIT_OR >> >>> <<)
       (js-bitop loc op type lhs rhs mode return conf))
      ((OR)
       (let ((lhsv (gensym 'lhs)))
	  `(let ((,(type-ident lhsv (j2s-vtype lhs) conf)
		  ,(j2s-scheme lhs mode return conf)))
	      (if ,(if (eq? (j2s-vtype lhs) 'bool)
		       lhsv
		       (j2s-cast lhsv lhs (j2s-vtype lhs) 'bool conf))
		  ,(j2s-cast lhsv lhs (j2s-vtype lhs) type conf)
		  ,(j2s-cast (j2s-scheme rhs mode return conf) rhs
		      (j2s-vtype rhs) type conf)))))
      ((&&)
       (let ((lhsv (gensym 'lhs)))
	  `(let ((,(type-ident lhsv (j2s-vtype lhs) conf)
		  ,(j2s-scheme lhs mode return conf)))
	      (if ,(if (eq? (j2s-vtype lhs) 'bool)
		       lhsv
		       (j2s-cast lhsv lhs (j2s-vtype lhs) 'bool conf))
		  ,(j2s-cast (j2s-scheme rhs mode return conf) rhs
		      (j2s-vtype rhs) type conf)
		  ,(j2s-cast lhsv lhs (j2s-vtype lhs) type conf)))))
      ((MAX)
       (js-min-max loc '>>= lhs rhs mode return conf))
      ((MIN)
       (js-min-max loc '<<= lhs rhs mode return conf))
      (else
       (with-tmp lhs rhs mode return conf 'any
	  (lambda (left right)
	     (js-binop loc op left lhs right rhs conf))))))

;*---------------------------------------------------------------------*/
;*    j2s-in? ...                                                      */
;*---------------------------------------------------------------------*/
(define (j2s-in? loc id obj)
   (if (> (bigloo-debug) 0)
       `(js-in?/debug %this ',loc ,id ,obj)
       `(js-in? %this ,id ,obj)))

;*---------------------------------------------------------------------*/
;*    js-binop ...                                                     */
;*    -------------------------------------------------------------    */
;*    This function is called with left and right being either         */
;*    atoms or variable references. Hence it does not generate         */
;*    bindings.                                                        */
;*---------------------------------------------------------------------*/
(define (js-binop loc op lhs l rhs r conf)

   (define (strict-equal-uint32 lhs rhs tr)
      (cond
	 ((eq? tr 'uint32)
	  `(=u32 ,lhs ,rhs))
	 ((eq? tr 'int32)
	  `(and (>=s32 ,rhs 0) (=u32 ,lhs (int32->uint32 ,rhs))))
	 ((memq tr '(integer int53))
	  `(and (>=fx ,rhs 0) (=u32 ,lhs (fixnum->uint32 ,rhs))))
	 ((eq? tr 'real)
	  `(=fl ,(asreal lhs 'uint32) ,rhs))
	 (else
	  `(js-strict-equal-no-string? ,(asreal lhs 'uint32) ,rhs))))

   (define (strict-equal-int32 lhs rhs tr)
      (cond
	 ((eq? tr 'uint32)
	  `(and (>=s32 ,lhs 0) (=u32 (int32->uint32 ,lhs) ,rhs)))
	 ((eq? tr 'int32)
	  `(=s32 ,lhs ,rhs))
	 ((memq tr '(integer int53))
	  `(=s32 (int32->fixnum ,lhs) ,rhs))
	 ((eq? tr 'real)
	  `(=fl (int32->flonum ,lhs) ,rhs))
	 (else
	  `(js-strict-equal-no-string? (int32->flonum ,lhs) ,rhs))))
      
   (define (strict-equal lhs rhs)
      (let ((tl (j2s-vtype l))
	    (tr (j2s-vtype r)))
	 (cond
	    ((eq? tl 'uint32)
	     (strict-equal-uint32 lhs rhs tr))
	    ((eq? tr 'uint32)
	     (strict-equal-uint32 rhs lhs tl))
	    ((eq? tr 'int32)
	     (strict-equal-int32 rhs lhs tl))
	    ((or (type-cannot? tr '(string)) (type-cannot? tl '(string)))
	     `(js-strict-equal-no-string? ,lhs ,rhs))
	    (else
	     `(js-strict-equal? ,lhs ,rhs)))))

   (case op
      ((==)
       `(js-equal? ,lhs ,rhs %this))
      ((!=)
       `(not (js-equal? ,lhs ,rhs %this)))
      ((eq?)
       `(eq? ,lhs ,rhs))
      ((===)
       (strict-equal lhs rhs))
      ((!==)
       `(not ,(strict-equal lhs rhs)))
      ((eq?)
       `(eq? ,lhs ,rhs))
      ((!eq?)
       `(not (eq? ,lhs ,rhs)))
      ((eqil?)
       `(js-eqil? ,lhs ,rhs))
      ((eqir?)
       `(js-eqir? ,lhs ,rhs))
      ((!eqil?)
       `(not (js-eqil? ,lhs ,rhs)))
      ((!eqir?)
       `(not (js-eqir? ,lhs ,rhs)))
      ((!eqil?)
       `(not (js-eqil? ,lhs ,rhs)))
      ((!eqir?)
       `(not (js-eqir? ,lhs ,rhs)))
      ((<-)
       `(js<- ,lhs ,rhs %this))
      ((instanceof)
       (if (> (bigloo-debug) 0)
	   `(js-instanceof?/debug %this ',loc ,lhs ,rhs)
	   `(js-instanceof? %this ,lhs ,rhs)))
      ((in)
       (j2s-in? loc lhs rhs))
      ((+)
       `(js+ ,(box lhs (j2s-vtype l) conf)
	   ,(box rhs (j2s-vtype r) conf)
	   %this))
      ((<)
       `(<js ,lhs ,rhs %this))
      ((<=)
       `(<=js ,lhs ,rhs %this))
      ((>)
       `(>js ,lhs ,rhs %this))
      ((>=)
       `(>=js ,lhs ,rhs %this))
      ((- * / % & ^ >> >>> << OR &&)
       (error "js-binop" "should not be here" op))
      (else
       `(,op ,lhs ,rhs %this))))

;*---------------------------------------------------------------------*/
;*    js-binop-arithmetic ...                                          */
;*    -------------------------------------------------------------    */
;*    This function is called with left and right being either         */
;*    atoms or variable references. Hence it does not generate         */
;*    bindings.                                                        */
;*---------------------------------------------------------------------*/
(define (js-binop-arithmetic loc op left l right r conf)
   (let ((tl (j2s-vtype l))
	 (tr (j2s-vtype r)))
      (case op
	 ((-)
	  `(-js ,(box left tl conf) ,(box right tr conf) %this))
	 ((*)
	  `(*js ,(box left tl conf) ,(box right tr conf) %this))
	 ((**)
	  `(**js ,(box left tl conf) ,(box right tr conf) %this))
	 ((/)
	  `(/js ,(box left tl conf) ,(box right tr conf) %this))
	 ((<)
	  `(<js ,(box left tl conf) ,(box right tr conf) %this))
	 ((<=)
	  `(<=js ,(box left tl conf) ,(box right tr conf) %this))
	 ((>)
	  `(>js ,(box left tl conf) ,(box right tr conf) %this))
	 ((>=)
	  `(>=js ,(box left tl conf) ,(box right tr conf) %this))
	 ((&)
	  `(bit-andjs ,(box left tl conf) ,(box right tr conf) %this))
	 ((BIT_OR)
	  `(bit-orjs ,(box left tl conf) ,(box right tr conf) %this))
	 ((^)
	  `(bit-xorjs ,(box left tl conf) ,(box right tr conf) %this))
	 ((>>)
	  `(bit-rshjs ,(box left tl conf) ,(box right tr conf) %this))
	 ((>>>)
	  `(bit-urshjs ,(box left tl conf) ,(box right tr conf) %this))
	 ((<<)
	  `(bit-lshjs ,(box left tl conf) ,(box right tr conf) %this))
	 (else
	  (error "js-binop-arihmetic" "should not be here" op)))))

;*---------------------------------------------------------------------*/
;*    with-tmp-flip ...                                                */
;*---------------------------------------------------------------------*/
(define (with-tmp-flip flip lhs rhs mode return conf optype gen::procedure)
   
   (define (simple? expr)
      (cond
	 ((isa? expr J2SRef)
	  #t)
	 ((isa? expr J2SGlobalRef)
	  #f)
	 ((isa? expr J2SHopRef)
	  #t)
	 ((isa? expr J2SLiteral)
	  #t)
	 ((isa? expr J2SBinary)
	  (with-access::J2SBinary expr (lhs rhs)
	     (and (simple? lhs) (simple? rhs))))
	 ((isa? expr J2SUnary)
	  (with-access::J2SUnary expr (expr)
	     (simple? expr)))
	 ((isa? expr J2SParen)
	  (with-access::J2SParen expr (expr)
	     (simple? expr)))
	 ((isa? expr J2SCast)
	  (with-access::J2SCast expr (expr)
	     (simple? expr)))
	 (else
	  #f)))
   
   (define (atom? expr)
      (or (number? expr)
	  (string? expr)
	  (boolean? expr)
	  (equal? expr '(js-undefined))
	  (equal? expr '(js-null))
	  (match-case expr
	     ((js-ascii->jsstring (? string?)) #t)
	     ((js-utf8->jsstring (? string?)) #t)
	     (else #f))))
   
   (let* ((scmlhs (j2s-scheme lhs mode return conf))
	  (scmrhs (j2s-scheme rhs mode return conf))
	  (testl (or (atom? scmlhs) (and (symbol? scmlhs) (simple? rhs))))
	  (testr (or (atom? scmrhs) (and (symbol? scmrhs) (simple? lhs)))))
      (cond
	 ((and testl testr)
	  (gen scmlhs scmrhs))
	 (testl
	  (let ((right (gensym 'rhs)))
	     `(let ((,(type-ident right (j2s-vtype rhs) conf) ,scmrhs))
		 ,(gen scmlhs right))))
	 (testr
	  (let ((left (gensym 'lhs)))
	     `(let ((,(type-ident left (j2s-vtype lhs) conf) ,scmlhs))
		 ,(gen left scmrhs))))
	 (else
	  (let ((left (gensym 'lhs))
		(right (gensym 'rhs)))
	     (if flip 
		 `(let* ((,(type-ident right (j2s-vtype rhs) conf) ,scmrhs)
			 (,(type-ident left (j2s-vtype lhs) conf) ,scmlhs))
		     ,(gen left right))
		 `(let* ((,(type-ident left (j2s-vtype lhs) conf) ,scmlhs)
			 (,(type-ident right (j2s-vtype rhs) conf) ,scmrhs))
		     ,(gen left right))))))))

;*---------------------------------------------------------------------*/
;*    with-tmp ...                                                     */
;*---------------------------------------------------------------------*/
(define (with-tmp lhs rhs mode return conf optype gen::procedure)
   (with-tmp-flip #f lhs rhs mode return conf optype gen))

;*---------------------------------------------------------------------*/
;*    js-cmp ...                                                       */
;*    -------------------------------------------------------------    */
;*    The compilation of the comparison functions.                     */
;*---------------------------------------------------------------------*/
(define (js-cmp loc o::symbol lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   
   (define (notop o expr)
      (if (memq o '(!= !==))
	  (match-case expr
	     (((kwote not) ?val) val)
	     (else `(not ,expr)))
	  expr))
   
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tl (j2s-vtype lhs))
	       (tr (j2s-vtype rhs))
	       (op (case o
		      ((!=) '==)
		      ((!==) '===)
		      (else o))))
	    (epairify loc
	       (notop o
		  (cond
		     ((eq? tl 'int32)
		      (binop-int32-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'int32)
		      (binop-int32-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((eq? tl 'uint32)
		      (binop-uint32-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'uint32)
		      (binop-uint32-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((eq? tl 'int53)
		      (binop-int53-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'int53)
		      (binop-int53-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((eq? tl 'integer)
		      (binop-integer-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'integer)
		      (binop-integer-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((eq? tl 'bint)
		      (binop-bint-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'bint)
		      (binop-bint-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((eq? tl 'real)
		      (binop-real-xxx op 'bool
			 lhs tl left rhs tr right conf #f))
		     ((eq? tr 'real)
		      (binop-real-xxx op 'bool
			 rhs tr right lhs tl left conf #t))
		     ((or (is-hint? lhs 'real) (is-hint? rhs 'real))
		      (if-flonums? left tl right tr
			 (binop-flonum-flonum op 'bool
			    (asreal left tl)
			    (asreal right tr)
			    #f)
			 (binop-any-any op 'bool
			    (box left tl conf)
			    (box right tr conf)
			    #f)))
		     ((and (eq? tl 'number) (eq? tr 'number))
		      (if-fixnums? left tl right tr
			 (binop-fixnum-fixnum op 'bool
			    (asfixnum left tl)
			    (asfixnum right tr)
			    #f)
			 (if-flonums? left tl right tr
			    (binop-flonum-flonum op 'bool
			       (asreal left tl)
			       (asreal right tr)
			       #f)
			    (binop-number-number op 'bool
			       (box left tl conf)
			       (box right tr conf)
			       #f))))
		     (else
		      (if-fixnums? left tl right tr
			 (binop-fixnum-fixnum op 'bool
			    (asfixnum left tl)
			    (asfixnum right tr)
			    #f)
			 (if-flonums? left tl right tr
			    (binop-flonum-flonum op 'bool
			       (asreal left tl)
			       (asreal right tr)
			       #f)
			    (let ((op (if (and (eq? op '===)
					       (or (type-cannot? tl '(string))
						   (type-cannot? tr '(string))))
					  'js-strict-equal-no-string?
					  op)))
			       (binop-any-any op 'bool
				  (box left tl conf)
				  (box right tr conf)
				  #f))))))))))))

;*---------------------------------------------------------------------*/
;*    js-min-max ...                                                   */
;*---------------------------------------------------------------------*/
(define (js-min-max loc op lhs rhs mode return conf)
   (with-tmp lhs rhs mode return conf 'any
      (lambda (left right)
	 (let ((lhs (if (symbol? left)
			(with-access::J2SExpr lhs (loc)
			   (instantiate::J2SHopRef
			      (type (j2s-vtype lhs))
			      (loc loc)
			      (id left)))
			lhs))
	       (rhs (if (symbol? right)
			(with-access::J2SExpr rhs (loc)
			   (instantiate::J2SHopRef
			      (type (j2s-vtype rhs))
			      (loc loc)
			      (id right)))
			rhs)))
	    `(if ,(js-cmp loc op  lhs rhs mode return conf)
		 ,left ,right)))))

;*---------------------------------------------------------------------*/
;*    js-equality ...                                                  */
;*---------------------------------------------------------------------*/
(define (js-equality loc op::symbol type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)

   (define (type-fixnum? ty)
      (memq ty '(int32 uint32 integer bint)))

   (define (j2s-aref-length? expr::J2SExpr)
      (when (isa? expr J2SAccess)
	 (with-access::J2SAccess expr (obj field)
	    (when (j2s-field-length? field)
	       (isa? obj J2SAref)))))
   
   (define (j2s-cast-aref-length? expr::J2SExpr)
      (when (isa? expr J2SCast)
	 (with-access::J2SCast expr (expr)
	    (j2s-aref-length? expr))))

   (define (cast-aref::J2SAref expr::J2SCast)
      (when (isa? expr J2SCast)
	 (with-access::J2SCast expr (expr)
	    (aref expr))))
   
   (define (aref::J2SAref expr::J2SAccess)
      (with-access::J2SAccess expr (obj field)
	 obj))

   (define (j2s-case-type expr test #!key
	      (number 'false)
	      (string 'false)
	      (object 'false)
	      (boolean 'false)
	      (regexp 'false)
	      (function 'false)
	      (undefined 'false)
	      (pair 'false)
	      (symbol 'false))
      (case (j2s-type expr)
	 ((int30 int32 uint32 fixnum integer real number) number)
	 ((string) string)
	 ((object) object)
	 ((boolean) boolean)
	 ((regexp) regexp)
	 ((function) function)
	 ((undefined) undefined)
	 ((pair) pair)
	 ((symbol) pair)
	 (else test)))
   
   (define (j2s-typeof-predicate this::J2SExpr expr)
      (when (isa? this J2SUnary)
	 (with-access::J2SUnary this (op)
	    (when (eq? op 'typeof)
	       (when (or (isa? expr J2SString) (isa? expr J2SNativeString))
		  (with-access::J2SLiteralValue expr (val)
		     (cond
			((string=? val "number")
			 (j2s-case-type expr 'js-number? :number 'true))
			((string=? val "function")
			 (j2s-case-type expr 'js-function? :function 'true))
			((string=? val "string")
			 (j2s-case-type expr 'js-jsstring? :string 'true))
			((string=? val "undefined")
			 (j2s-case-type expr 'js-undefined? :undefined 'true))
			((string=? val "boolean")
			 (j2s-case-type expr 'boolean? :boolean 'true))
			((string=? val "pair")
			 (j2s-case-type expr 'pair? :pair 'true))
			((string=? val "symbol")
			 (j2s-case-type expr 'js-symbol? :symbol 'true))
			(else
			 #f))))))))

   (define (equality-int32 op lhs tl rhs tr mode return conf flip::bool)
      ;; tl == int32, tr = ???
      (with-tmp-flip flip lhs rhs mode return conf 'any
	 (lambda (left right)
	    (let loop ((op op))
	       (cond
		  ((eq? op '!=)
		   `(not ,(loop '==)))
		  ((eq? op '!==)
		   `(not ,(loop '===)))
		  ((eq? tr 'int32)
		   `(=s32 ,left ,right))
		  ((eq? tr 'uint32)
		   (cond
		      ((inrange-int32? rhs)
		       `(=s32 ,left ,(asint32 right tr)))
		      ((m64? conf)
		       `(=fx ,(asfixnum left tl) ,(asfixnum right tr)))
		      (else
		       `(and (=s32 ,left ,(asint32 right tr))
			     (>=s32 ,left #s32:0)))))
		  ((eq? tr 'integer)
		   `(=fx ,(asfixnum left tl) ,right))
		  ((eq? tr 'real)
		   `(=fl ,(asreal left tl) ,right))
		  ((eq? op '===)
		   (if (memq (j2s-type rhs) '(int32 uint32))
		       `(=fx ,(asfixnum left tl) ,right)
		       `(if (fixnum? ,right)
			    (=fx ,(asfixnum left tl) ,right)
			    (js-eqil?
			       ,(box left tl conf)
			       ,(box right tr conf)))))
		  ((not (eq? tr 'any))
		   `(js-equal-sans-flonum? ,(asfixnum left tl) ,right %this))
		  (else
		   `(js-equal-fixnum? ,(asfixnum left tl) ,right %this)))))))

   (define (equality-uint32 op lhs tl rhs tr mode return conf flip::bool)
      ;; tl == uint32, tr = ???
      (with-tmp-flip flip lhs rhs mode return conf 'any
	 (lambda (left right)
	    (let loop ((op op))
	       (cond
		  ((eq? op '!=)
		   `(not ,(loop '==)))
		  ((eq? op '!==)
		   `(not ,(loop '===)))
		  ((eq? tr 'uint32)
		   `(us32 ,left right))
		  ((eq? tr 'int32)
		   (cond
		      ((inrange-int32? lhs)
		       `(=s32 ,(asint32 left tl) ,right))
		      ((m64? conf)
		       `(=fx ,(asfixnum left tl) ,(asfixnum right tr)))
		      (else
		       `(and (=s32 ,(asint32 left tl) ,right)
			     (>=s32 ,right #s32:0)))))
		  ((or (eq? tr 'integer) (eq? tr 'int53))
		   `(=fx ,(asfixnum left tl) ,right))
		  ((eq? tr 'real)
		   `(=fl ,(asreal left tl) ,right))
		  ((eq? op '===)
		   (if (memq (j2s-type rhs) '(int32 uint32))
		       (if (inrange-int32? lhs)
			   `(=fx ,(asfixnum left tl) ,right)
			   `(and (=fx ,(asfixnum left tl) ,right)
				 (>=fx ,right 0)))
		       `(if (fixnum? ,right)
			    ,(if (inrange-int32? lhs)
				 `(=fx ,(asfixnum left tl) ,right)
				 `(and (=fx ,(asfixnum left tl) ,right)
				       (>=fx ,right 0)))
			    (js-eqil?
			       ,(box left tl conf)
			       ,(box right tr conf)))))
		  (else
		   (if (inrange-int32? lhs)
		       `(if (fixnum? ,right)
			    (=fx ,(asfixnum left tl) ,right)
			    (js-equal? ,(asfixnum left tl) ,right %this))
		       (if (memq (j2s-type rhs) '(int32 uint32))
			   `(and (=fx ,(asfixnum left tl) ,right)
				  (>=fx ,right 0))
			   `(if (fixnum? ,right)
				(and (=fx ,(asfixnum left tl) ,right)
				     (>=fx ,right 0))
				(js-equal? 
				   ,(asreal left tl)
				   ,(box right tr conf)
				   %this))))))))))

   (define (equality-string op lhs tl rhs tr mode return conf flip)
      (with-tmp-flip flip lhs rhs mode return conf 'any
	 (lambda (left right)
	    (if (or (type-cannot? tl '(string)) (type-cannot? tr '(string)))
		(eq? op '!==)
		(if (eq? op '!==)
		    `(not (js-eqstring? ,left ,right))
		    `(js-eqstring? ,left ,right))))))
		
   (define (typeof-expr expr mode return conf)
      (cond
	 ((isa? expr J2SUnresolvedRef)
	  ;; http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.3
	  (with-access::J2SUnresolvedRef expr (id loc cache)
	     (j2s-unresolved id #f cache loc)))
	 ((isa? expr J2SParen)
	  (with-access::J2SParen expr (expr)
	     (typeof-expr expr mode return conf)))
	 (else
	  (j2s-scheme expr mode return conf))))

   (define (typeof/pred expr pred)
      (cond
	 ((eq? pred 'true)
	  `(begin
	      ,(typeof-expr expr mode return conf)
	      ,(if (memq op '(!= !==)) #f #t)))
	 ((eq? pred 'false)
	  `(begin
	      ,(typeof-expr expr mode return conf)
	      ,(if (memq op '(!= !==)) #f #t)))
	 (else
	  (let ((t `(,pred ,(box (typeof-expr expr mode return conf)
			       (j2s-vtype expr)
			       conf))))
	     (if (memq op '(!= !==)) `(not ,t) t)))))
   
   (let ((tl (j2s-vtype lhs))
	 (tr (j2s-vtype rhs)))
      (cond
	 ((j2s-typeof-predicate lhs rhs)
	  =>
	  (lambda (pred)
	     (with-access::J2SUnary lhs (expr)
		(typeof/pred expr pred))))
	 ((j2s-typeof-predicate rhs lhs)
	  =>
	  (lambda (pred)
	     (with-access::J2SUnary rhs (expr)
		(typeof/pred expr pred))))
	 ((and (is-uint32? lhs) (is-uint32? rhs))
	  (cond
	     ((j2s-aref-length? rhs)
	      (with-access::J2SAref (aref rhs) (field alen)
		 (let ((test `(or (=u32 %lhs ,(j2s-decl-scheme-id alen))
				  (=u32 %lhs ,(j2s-scheme rhs mode return conf)))))
		    `(let ((%lhs ,(j2s-scheme lhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     ((j2s-aref-length? lhs)
	      (with-access::J2SAref (aref lhs) (field alen)
		 (let ((test `(or (=u32 ,(j2s-decl-scheme-id alen) %rhs)
				  (=u32 ,(j2s-scheme rhs mode return conf)
				     %rhs))))
		    `(let ((%rhs ,(j2s-scheme rhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     (else
	      (js-cmp loc op lhs rhs mode return conf))))
	 ((and (type-fixnum? tl) (type-fixnum? tr))
	  (cond
	     ((j2s-cast-aref-length? rhs)
	      (with-access::J2SAref (cast-aref rhs) (field alen)
		 (let ((test `(or (=fx %lhs ,(j2s-decl-scheme-id alen))
				  (=fx %lhs ,(j2s-scheme rhs mode return conf)))))
		    `(let ((%lhs ,(j2s-scheme lhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     ((j2s-cast-aref-length? lhs)
	      (with-access::J2SAref (cast-aref lhs) (field alen)
		 (let ((test `(or (=fx ,(j2s-decl-scheme-id alen) %rhs)
				  (=fx ,(j2s-scheme rhs mode return conf)
				     %rhs))))
		    `(let ((%rhs ,(j2s-scheme rhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     (else
	      (js-cmp loc op lhs rhs mode return conf))))
	 ((eq? tl 'int32)
	  (equality-int32 op lhs tl rhs tr mode return conf #f))
	 ((eq? tr 'int32)
	  (equality-int32 op rhs tr lhs tl mode return conf #t))
	 ((eq? tl 'uint32)
	  (equality-uint32 op lhs tl rhs tr mode return conf #f))
	 ((eq? tr 'uint32)
	  (equality-uint32 op rhs tr lhs tl mode return conf #t))
	 ((and (memq op '(=== !==)) (eq? tl 'string))
	  (equality-string op rhs tr lhs tl mode return conf #f))
	 ((and (memq op '(=== !==)) (eq? tr 'string))
	  (equality-string op rhs tr lhs tl mode return conf #t))
	 ((and (eq? tl 'real) (eq? tr 'real))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(if (memq op '(== ===))
		    `(=fl ,left ,right)
		    `(not (=fl ,left ,right))))))
	 ((and (eq? tl 'string) (eq? tr 'string))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(if (memq op '(== ===))
		    `(js-jsstring=? ,left ,right)
		    `(not (js-jsstring=? ,left ,right))))))
	 ((and (eq? tl 'bool) (eq? tr 'bool))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(if (memq op '(== ===))
		    `(eq? ,left ,right)
		    `(not (eq? ,left ,right))))))
	 ((and (or (eq? tl 'bool) (eq? tr 'bool)) (memq op '(=== !==)))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(if (eq? op '===)
		    `(eq? ,left ,right)
		    `(not (eq? ,left ,right))))))
	 ((and (is-number? lhs) (is-number? rhs))
	  (cond
	     ((j2s-cast-aref-length? rhs)
	      (with-access::J2SAref (cast-aref rhs) (field alen)
		 (let ((test `(or (= %lhs ,(j2s-decl-scheme-id alen))
				  (= %lhs ,(j2s-scheme rhs mode return conf)))))
		    `(let ((%lhs ,(j2s-scheme lhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     ((j2s-cast-aref-length? lhs)
	      (with-access::J2SAref (cast-aref lhs) (field alen)
		 (let ((test `(or (= ,(j2s-decl-scheme-id alen) %rhs)
				  (= ,(j2s-scheme rhs mode return conf) %rhs))))
		    `(let ((%rhs ,(j2s-scheme rhs mode return conf)))
			,(if (memq op '(!= !==))
			     (js-not test)
			     test)))))
	     (else
	      (js-cmp loc op lhs rhs mode return conf))))
	 ((and (memq op '(== !=))
	       (or (memq tl '(bool string object array))
		   (memq tr '(bool string object array))))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(if (eq? op '!=)
		    `(not (js-equal-sans-flonum? ,left ,right %this))
		    `(js-equal-sans-flonum? ,left ,right %this)))))
	 ((or (memq tl '(undefined null)) (memq tr '(undefined null)))
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(case op
		   ((!==)
		    `(not (eq? ,left ,right)))
		   ((===)
		    `(eq? ,left ,right))
		   ((==)
		    (if (memq (j2s-vtype lhs) '(undefined null))
			`(js-null-or-undefined? ,right)
			`(js-null-or-undefined? ,left)))
;* 			`(or (eq? (js-undefined) ,right) (eq? (js-null) ,right)) */
;* 			`(or (eq? ,left (js-undefined)) (eq? ,left (js-null))))) */
		   ((!=)
		    (if (memq (j2s-vtype lhs) '(undefined null))
			`(not (js-null-or-undefined? ,right))
			`(not (js-null-or-undefined? ,left))))
;* 			`(not (or (eq? (js-undefined) ,right) (eq? (js-null) ,right))) */
;* 			`(not (or (eq? ,left (js-undefined)) (eq? ,left (js-null)))))) */
		   (else
		    (js-binop loc op left lhs right rhs conf))))))
	 (else
	  (with-tmp lhs rhs mode return conf 'any
	     (lambda (left right)
		(let ((op (cond
			     ((type-fixnum? tl)
			      (if (memq op '(== ===)) 'eqil? '!eqil?))
			     ((type-fixnum? tr)
			      (if (memq op '(== ===)) 'eqir? '!eqir?))
			     (else
			      op))))
		   (js-binop loc op left lhs right rhs conf))))))))

;*---------------------------------------------------------------------*/
;*    js-bitop ...                                                     */
;*---------------------------------------------------------------------*/
(define (js-bitop loc op::symbol type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   
   (define (bitop op)
      (case op
	 ((&) 'bit-ands32)
	 ((BIT_OR) 'bit-ors32)
	 ((^) 'bit-xors32)
	 ((>>) 'bit-rshs32)
	 ((>>>) 'bit-urshu32)
	 ((<<) 'bit-lshs32)
	 (else (error "bitop" "unknown operator" op))))

   (define (bitopjs op)
      (case op
	 ((&) 'bit-andjs)
	 ((BIT_OR) 'bit-orjs)
	 ((^) 'bit-xorjs)
	 ((>>) 'bit-rshjs)
	 ((>>>) 'bit-urshjs)
	 ((<<) 'bit-lshjs)
	 (else (error "bitop" "unknown operator" op))))
   
   (define (mask32 sexpr expr::J2SExpr)
      (cond
	 ((fixnum? sexpr)
	  (bit-and sexpr 31))
	 ((uint32? sexpr)
	  (uint32->fixnum (bit-andu32 sexpr #u32:31)))
	 ((int32? sexpr)
	  (int32->fixnum (bit-ands32 sexpr #s32:31)))
	 ((inrange-32? expr)
	  (case (j2s-vtype expr)
	     ((int32) `(bit-and ,(asfixnum sexpr 'int32) 31))
	     ((uint32) `(bit-and ,(asfixnum sexpr 'uint32) 31))
	     (else `(bit-and ,sexpr 31))))
	 (else
	  (case (j2s-vtype expr)
	     ((int32) `(bit-and ,(asfixnum sexpr 'int32) 31))
	     ((uint32) `(bit-and ,(asfixnum sexpr 'uint32) 31))
	     ((integer int53) `(bit-and ,sexpr 31))
	     ((real) `(bit-and (flonum->fixnum ,sexpr) 31))
	     (else `(bit-and (js-tointeger ,sexpr %this) 31))))))
   
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tl (j2s-vtype lhs))
	       (tr (j2s-vtype rhs)))
	    (epairify loc
	       (cond
		  ((memq type '(int32 uint32))
		   (case op
		      ((>> <<)
		       (if (and (number? right) (= right 0) (eq? type tl))
			   (toint32 left tl conf)
			   `(,(bitop op) ,(toint32 left tl conf) ,(mask32 right rhs))))
		      ((>>>)
		       `(,(bitop op) ,(touint32 left tl conf) ,(mask32 right rhs)))
		      (else
		       `(,(bitop op) ,(toint32 left tl conf) ,(toint32 right tr conf)))))
		  ((memq tr '(int32 uint32 integer))
		   (case op
		      ((>> <<)
		       (j2s-cast
			  (if (and (number? right) (= right 0) (eq? type tl))
			      (toint32 left tl conf)
			      `(,(bitop op)
				,(toint32 left tl conf) ,(mask32 right rhs)))
			  #f 'int32 type conf))
		      ((>>>)
		       (j2s-cast
			  `(,(bitop op)
			    ,(touint32 left tl conf) ,(mask32 right rhs))
			  #f 'uint32 type conf))
		      (else
		       (j2s-cast
			  `(,(bitop op)
			    ,(toint32 left tl conf) ,(toint32 right tr conf))
			  #f 'int32 type conf))))
		  ((memq tl '(int32 uint32 integer))
		   (case op
		      ((>> <<)
		       (j2s-cast
			  `(,(bitop op)
			    ,(asint32 left tl) ,(mask32 right rhs))
			  #f 'int32 type conf))
		      ((>>>)
		       (j2s-cast
			  `(,(bitop op)
			    ,(asuint32 left tl) ,(mask32 right rhs))
			  #f 'uint32 type conf))
		      (else
		       (j2s-cast
			  `(,(bitop op)
			    ,(asint32 left tl) ,(toint32 right tr conf))
			  #f 'int32 type conf))))
		  ((memq op '(& ^ BIT_OR))
		   `(if (and (fixnum? ,left) (fixnum? ,right))
			(js-int32-tointeger
			   (,(bitop op)
			    (fixnum->int32 ,left) (fixnum->int32 ,right)))
			(,(bitopjs op) ,left ,right %this)))
		  (else
		   `(,(bitopjs op)
		     ,(box left tl conf) ,(box right tr conf) %this))))))))

;*---------------------------------------------------------------------*/
;*    js-binop-add ...                                                 */
;*---------------------------------------------------------------------*/
(define (js-binop-add loc type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   
   (define (str-append flip left right)
      (if flip
	  `(js-jsstring-append ,right ,left)
	  `(js-jsstring-append ,left ,right)))
   
   (define (add-string loc type left tl lhs right tr rhs
	      mode return conf flip)
      (cond
	 ((or (eq? tr 'string) (eq? (j2s-type right) 'string))
	  (str-append flip left right))
	 ((eq? tr 'int32)
	  (str-append flip
	     left
	     `(js-integer->jsstring (int32->fixnum ,right))))
	 ((eq? tr 'uint32)
	  (str-append flip
	     left
	     `(js-integer->jsstring ,(asfixnum right 'uint32))))
	 ((memq tr '(integer int53))
	  (str-append flip
	     left
	     `(js-integer->jsstring ,right)))
	 ((eq? tr 'real)
	  (str-append flip
	     left
	     `(js-ascii->jsstring (js-real->string ,right))))
	 ((eq? tl 'number)
	  (str-append flip
	     `(if (fixnum? ,left)
		  (js-integer->jsstring ,left)
		  (js-ascii->jsstring (js-real->string ,left)))
	     right))
	 ((eq? tr 'number)
	  (str-append flip
	     left
	     `(if (fixnum? ,right)
		  (js-integer->jsstring ,right)
		  (js-ascii->jsstring (js-real->string ,right)))))
	 (else
	  (str-append flip
	     left
	     `(js-tojsstring (js-toprimitive ,right 'any %this) %this)))))
   
   (define (add loc type lhs rhs mode return conf)
      (with-tmp lhs rhs mode return conf type
	 (lambda (left right)
	    (let ((tl (j2s-vtype lhs))
		  (tr (j2s-vtype rhs)))
	       (cond
		  ((and (eq? type 'any)
			(or (and (eq? tl 'number) (memq tr '(int32 uint32)))
			    (and (memq tl '(int32 uint32)) (eq? tr 'number))))
		   ;; type is forced to any on prefix/suffix generic increments
		   ;; this case is used to generate smaller codes
		   (binop-any-any '+ type
		      (box left tl conf)
		      (box right tr conf)
		      #f))
		  ((eq? tl 'string)
		   (add-string loc type left tl lhs right tr rhs
		      mode return conf #f))
		  ((eq? tr 'string)
		   (add-string loc type right tr rhs left tl lhs
		      mode return conf #t))
		  ((eq? tl 'int32)
		   (binop-int32-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'int32)
		   (binop-int32-xxx '+ type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'uint32)
		   (binop-uint32-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'uint32)
		   (binop-uint32-xxx '+ type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'integer)
		   (binop-integer-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'integer)
		   (binop-integer-xxx '+ type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'bint)
		   (binop-bint-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'bint)
		   (binop-int53-xxx '+ type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'int53)
		   (binop-int53-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'int53)
		   (binop-bint-xxx '+ type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'real)
		   (binop-real-xxx '+ type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'real)
		   (binop-real-xxx '+ type rhs tr right lhs tl left conf #t))
		  (else
		   (if-fixnums? left tl right tr
		      (binop-fixnum-fixnum '+ type
			 (asfixnum left tl)
			 (asfixnum right tr)
			 #f)
		      (if-flonums? left tl right tr
			 (binop-flonum-flonum '+ type
			    (asreal left tl)
			    (asreal right tr)
			    #f)
			 (binop-any-any '+ type
			    (box left tl conf)
			    (box right tr conf)
			    #f)))))))))

   (if (type-number? type)
       (js-arithmetic-addsub loc '+ type lhs rhs mode return conf)
       (add loc type lhs rhs mode return conf)))

;*---------------------------------------------------------------------*/
;*    js-arithmetic-addsub ...                                         */
;*---------------------------------------------------------------------*/
(define (js-arithmetic-addsub loc op::symbol type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tl (j2s-vtype lhs))
	       (tr (j2s-vtype rhs)))
	    (epairify loc
	       (cond
		  ((and (eq? type 'any)
			(or (and (eq? tl 'number) (memq tr '(int32 uint32)))
			    (and (memq tl '(int32 uint32)) (eq? tr 'number))))
		   ;; type is forced to any on prefix/suffix generic increments
		   ;; this case is used to generate smaller codes
		   (binop-any-any op type
		      (box left tl conf)
		      (box right tr conf)
		      #f))
		  ((eq? tl 'int32)
		   (binop-int32-xxx op type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'int32)
		   (binop-int32-xxx op type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'uint32)
		   (binop-uint32-xxx op type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'uint32)
		   (binop-uint32-xxx op type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'integer)
		   (binop-integer-xxx op type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'integer)
		   (binop-integer-xxx op type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'bint)
		   (binop-bint-xxx op type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'bint)
		   (binop-bint-xxx op type rhs tr right lhs tl left conf #t))
		  ((eq? tl 'real)
		   (binop-real-xxx op type lhs tl left rhs tr right conf #f))
		  ((eq? tr 'real)
		   (binop-real-xxx op type rhs tr right lhs tl left conf #t))
		  ((and (is-hint? lhs 'real) (is-hint? rhs 'real))
		   (if-flonums? left tl right tr
		      (binop-flonum-flonum op type
			 (asreal left tl)
			 (asreal right tr)
			 #f)
		      (binop-number-number op type
			 (box left tl conf)
			 (box right tr conf)
			 #f)))
		  ((and (eq? op '-) (or (is-hint? lhs 'real) (is-hint? rhs 'real)))
		   (if-flonums? left tl right tr
		      (binop-flonum-flonum op type
			 (asreal left tl)
			 (asreal right tr)
			 #f)
		      (binop-number-number op type
			 (box left tl conf)
			 (box right tr conf)
			 #f)))
		  ((and (eq? tl 'number) (eq? tr 'number))
		   (if-fixnums? left tl right tr
		      (binop-fixnum-fixnum op type
			 (asfixnum left tl)
			 (asfixnum right tr)
			 #f)
		      (if-flonums? left tl right tr
			 (binop-flonum-flonum op type
			    (asreal left tl)
			    (asreal right tr)
			    #f)
			 (binop-number-number op type
			    (box left tl conf)
			    (box right tr conf)
			    #f))))
		  (else
		   (if-fixnums? left tl right tr
		      (binop-fixnum-fixnum op type
			 (asfixnum left tl)
			 (asfixnum right tr)
			 #f)
		      (if-flonums? left tl right tr
			 (binop-flonum-flonum op type
			    (asreal left tl)
			    (asreal right tr)
			    #f)
			 (binop-any-any op type
			    (box left tl conf)
			    (box right tr conf)
			    #f))))))))))

;*---------------------------------------------------------------------*/
;*    js-arithmetic-mul ...                                            */
;*---------------------------------------------------------------------*/
(define (js-arithmetic-mul loc type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tl (j2s-vtype lhs))
	       (tr (j2s-vtype rhs)))
	    (cond
	       ((eq? tl 'int32)
		(binop-int32-xxx '* type lhs tl left rhs tr right conf #f))
	       ((eq? tr 'int32)
		(binop-int32-xxx '* type rhs tr right lhs tl left conf #t))
	       ((eq? tl 'uint32)
		(binop-uint32-xxx '* type lhs tl left rhs tr right conf #f))
	       ((eq? tr 'uint32)
		(binop-uint32-xxx '* type rhs tr right lhs tl left conf #t))
	       ((eq? tl 'integer)
		(binop-integer-xxx '* type lhs tl left rhs tr right conf #f))
	       ((eq? tr 'integer)
		(binop-integer-xxx '* type rhs tr right lhs tl left conf #t))
	       ((eq? tl 'bint)
		(binop-bint-xxx '* type lhs tl left rhs tr right conf #f))
	       ((eq? tr 'bint)
		(binop-bint-xxx '* type rhs tr right lhs tl left conf #t))
	       ((eq? tl 'real)
		(binop-real-xxx '* type lhs tl left rhs tr right conf #f))
	       ((eq? tr 'real)
		(binop-real-xxx '* type rhs tr right lhs tl left conf #t))
	       ((eq? type 'real)
		(if-flonums? left tl right tr
		   (binop-flonum-flonum '* type
		      (asreal left tl)
		      (asreal right tr)
		      #f)
		   (binop-any-any '* type
		      (box left tl conf)
		      (box right tr conf)
		      #f)))
	       ((or (is-hint? lhs 'real) (is-hint? rhs 'real))
		(if-flonums? left tl right tr
		   (binop-flonum-flonum '* type
		      (asreal left tl)
		      (asreal right tr)
		      #f)
		   (binop-any-any '* type
		      (box left tl conf)
		      (box right tr conf)
		      #f)))
	       (else
		(if-fixnums? left tl right tr
		   (binop-fixnum-fixnum '* type
		      (asfixnum left tl)
		      (asfixnum right tr)
		      #f)
		   (if-flonums? left tl right tr
		      (binop-flonum-flonum '* type
			 (asreal left tl)
			 (asreal right tr)
			 #f)
		      (binop-any-any '* type
			 (box left tl conf)
			 (box right tr conf)
			 #f)))))))))

;*---------------------------------------------------------------------*/
;*    js-arithmetic-expt ...                                           */
;*---------------------------------------------------------------------*/
(define (js-arithmetic-expt loc type lhs::J2SExpr rhs::J2SExpr
	   mode return conf)
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tl (j2s-vtype lhs))
	       (tr (j2s-vtype rhs)))
	    (epairify loc
	       (cond
		  ((and (eq? tl 'int32) (eq? tr 'int32) (eq? type 'int32))
		   `(expts32 ,left ,right))
		  ((and (eq? tl 'uint32) (eq? tr 'uint32) (eq? type 'uint32))
		   `(exptu32 ,left ,right))
		  ((and (eq? tl 'int30) (eq? tr 'int30) (eq? type 'int30))
		   `(exptfx ,left ,right))
		  ((and (eq? tl 'real) (eq? tr 'real) (eq? type 'real))
		   `(exptfl ,left ,right))
		  (else
		   (let ((expr `(**js ,(box left tl conf) ,(box right tr conf) %this)))
		      (case type
			 ((uint32) (asuint32 expr 'real))
			 ((int32) (asint32 expr 'real))
			 ((fixnum int30) (asfixnum expr 'real))
			 (else expr))))))))))

;*---------------------------------------------------------------------*/
;*    js-arithmetic-div ...                                            */
;*---------------------------------------------------------------------*/
(define (js-arithmetic-div loc type lhs rhs
	   mode return conf)

   (define (power2 rsh)
      
      (define (find-power2 bitlsh one::obj n)
	 (let loop ((k 1))
	    (let ((m (bitlsh one k)))
	       (cond
		  ((= m n) (when (<fx k 31) k))
		  ((> m n) #f)
		  (else (loop (+fx k 1)))))))

      (define (find-power2fl n)
	 (when (and (integer? n) (=fl (/fl n 2.0) (roundfl (/fl n 2.0))))
	    (let loop ((k 1))
	       (let ((m (exptfl 2. (fixnum->flonum k))))
		  (cond
		     ((=fl m n) (when (<fx k 31) k))
		     ((>fl m n) #f)
		     (else (loop (+fx k 1))))))))
      
      (when (isa? rsh J2SNumber)
	 (with-access::J2SNumber rhs (val)
	    (cond
	       ((fixnum? val) (find-power2 bit-lsh 1 val))
	       ((uint32? val) (find-power2 bit-lshu32 #u32:1 val))
	       ((int32? val) (find-power2 bit-lshs32 #s32:1 val))
	       ((flonum? val) (find-power2fl val))))))
   
   (define (div-power2 k)
      
      (define (positive? n)
	 (with-access::J2SExpr n (range)
	    (and (interval? range) (>= (interval-min range) #l0))))
      
      (let ((n (gensym 'n)))
	 (case (j2s-vtype lhs)
	    ((uint32)
	     `(let ((,n ,(j2s-scheme lhs mode return conf)))
		 (if (=u32 (bit-andu32
			      ,n ,(fixnum->uint32 (-fx (bit-lsh 1 k) 1)))
			#u32:0)
		     (uint32->fixnum (bit-rshu32 ,n ,k))
		     (/fl (uint32->flonum ,n) (fixnum->flonum ,(bit-lsh 1 k))))))
	    ((int32)
	     `(let ((,n ,(j2s-scheme lhs mode return conf)))
		 (if (=s32 (bit-ands32
			      ,n ,(fixnum->int32 (-fx (bit-lsh 1 k) 1)))
			#s32:0)
		     ,(if (positive? lhs)
			  `(int32->fixnum (bit-rshs32 ,n ,k))
			  `(int32->fixnum (/pow2s32 ,n ,k)))
		     (/fl (int32->flonum ,n) (fixnum->flonum ,(bit-lsh 1 k))))))
	    (else
	     `(let ((,n ,(j2s-scheme lhs mode return conf)))
		 (if ,(if (memq (j2s-type lhs) '(int32 uint32))
			  `(=fx (bit-and ,n ,(-fx (bit-lsh 1 k) 1)) 0)
			  `(and (fixnum? ,n)
				(=fx (bit-and ,n ,(-fx (bit-lsh 1 k) 1)) 0)))
		     ,(if (positive? lhs)
			  `(bit-rsh ,n ,k)
			  `(/pow2fx ,n ,k))
		     (/js ,n ,(bit-lsh 1 k) %this)))))))

   (define (divs32 left right tl tr)
      (cond
	 ((and (eq? tl 'uint32) (eq? tr 'uint32))
	  `(uint32->int32 (/u32 ,left ,right)))
	 ((and (eq? tl 'int32) (eq? tr 'int32))
	  `(/s32 ,left ,right))
	 ((and (eq? tl 'int32) (eq? tr 'uint32) (inrange-int32? rhs))
	  `(/s32 ,left ,(asint32 right tr)))
	 ((and (eq? tr 'uint32) (inrange-int32? rhs))
	  (if-fixnum? left tl
	     `(fixnum->int32 (/fx ,(asfixnum left tl) ,(asfixnum right tr)))
	     `(js-toint32 (/js ,left ,right %this) %this)))
	 ((eq? tr 'int32)
	  (if-fixnum? left tl
	     `(fixnum->int32 (/fx ,(asfixnum left tl) ,(asfixnum right tr)))
	     `(js-toint32 (/js ,left ,right %this) %this)))
	 (else
	  (if-fixnums? left tl right tr
	     `(fixnum->int32 (/fx ,(asfixnum left tl) ,(asfixnum right tr)))
	     `(js-toint32 (/js ,left ,right %this) %this)))))

   (define (divu32 left right tl tr)
      (cond
	 ((and (eq? tl 'uint32) (eq? tr 'uint32))
	  `(/u32 ,left ,right))
	 ((and (eq? tl 'int32) (eq? tr 'int32))
	  `(int32->uint32 (/s32 ,left ,right)))
	 ((and (eq? tr 'int32) (inrange-uint32? rhs))
	  `(/u32 ,left ,(asuint32 right tr)))
	 (else
	  (if-fixnums? left tl right tr
	     `(fixnum->uint32 (/fx ,left ,right))
	     `(js-touint32 (/js ,left ,right %this) %this)))))

   (define (divjs left right tl tr)
      (cond
	 ((eq? tl 'uint32)
	  (if (eq? tr 'uint32)
	      `(if (and (not (=u32 ,right #u32:0))
			(=u32 (remainderu32 ,left ,right) #u32:0))
		   (js-uint32-tointeger (/u32 ,left ,right))
		   (/fl ,(asreal left tl)
		      ,(asreal right tr)))
	      `(/fl ,(asreal left tl) ,(todouble right tr conf))))
	 ((eq? tl 'int32)
	  (if (eq? tr 'int32)
	      `(if (and (not (=s32 ,right #s32:0))
			(=s32 (remainders32 ,left ,right) #s32:0))
		   (js-int32-tointeger (/s32 ,left ,right))
		   (/fl ,(asreal left tl)
		      ,(asreal right tr)))
	      `(/fl ,(asreal left tl) ,(todouble right tr conf))))
	 ((eq? tr 'uint32)
	  `(/fl ,(todouble left tl conf) ,(asreal right tr)))
	 ((eq? tr 'int32)
	  `(/fl ,(todouble left tl conf) ,(asreal right tr)))
	 ((eq? tl 'integer)
	  (if (eq? tr 'integer)
	      `(if (and (not (=fx ,right 0))
			(=fx (remainderfx ,left ,right) 0))
		   (/fx ,left ,right)
		   (/fl ,(todouble left tl conf) ,(todouble right tr conf)))
	      `(/fl ,(todouble left tl conf) ,(todouble right tr conf))))
	 ((or (eq? tl 'real) (eq? tr 'real))
	  `(/fl ,(todouble left tl conf) ,(todouble right tr conf)))
	 ((eq? tr 'integer)
	  `(/js ,(todouble left tl conf) ,(asreal right tr)))
	 ((eq? type 'real)
	  (if-flonums? left tl right tr
	     `(/fl ,left ,right)
	     `(/js ,left ,right %this)))
	 (else
	  (if-fixnums? left tl right tr
	     `(if (and (not (=fx ,right 0))
		       (=fx (remainderfx ,left ,right) 0))
		  (/fx ,left ,right)
		  (/fl ,(asreal left 'bint)
		     ,(asreal right 'bint)))
	     (if-flonums? left tl right tr
		`(/fl ,left ,right)
		`(/js ,left ,right %this))))))
   
   (let ((k (power2 rhs)))
      (if (and k (not (memq type '(int32 uint32))))
	  (div-power2 k)
	  (with-tmp lhs rhs mode return conf '/
	     (lambda (left right)
		(let ((tl (j2s-vtype lhs))
		      (tr (j2s-vtype rhs)))
		   (epairify loc
		      (case type
			 ((int32) (divs32 left right tl tr))
			 ((uint32) (divu32 left right tl tr))
			 (else (divjs left right tl tr))))))))))

;*---------------------------------------------------------------------*/
;*    js-arithmetic-% ...                                              */
;*---------------------------------------------------------------------*/
(define (js-arithmetic-% loc type lhs rhs mode return conf)
   
   (define (number totype)
      ;; if the range analysis has shown that the result is an uint, then
      ;; the library function will always return an int
      (if (eq? totype 'uint32) 'integer 'number))
   
   (with-tmp lhs rhs mode return conf '*
      (lambda (left right)
	 (let ((tlv (j2s-vtype lhs))
	       (trv (j2s-vtype rhs))
	       (tl (j2s-type lhs))
	       (tr (j2s-type rhs)))
	    (epairify loc
	       (cond
		  ((and (eq? tlv 'int32) (eq? trv 'int32))
		   (cond
		      ((inrange-positive? rhs)
		       (j2s-cast `(remainders32 ,left ,right)
			  rhs 'int32 type conf))
		      ((=s32 right #s32:0)
		       +nan.0)
		      (else
		       (remainders32-minus-zero left right
			  type lhs rhs mode return conf))))
		  ((and (eq? tlv 'uint32) (eq? trv 'uint32))
		   (cond
		      ((inrange-positive? rhs)
		       (j2s-cast `(remainderu32 ,left ,right)
			  lhs 'uint32 type conf))
		      (else
		       `(if (=u32 ,right #u32:0)
			    +nan.0
			    ,(j2s-cast `(remainderu32 ,left ,right)
				lhs 'uint32 type conf)))))
		  ((and (eq? tlv 'integer) (eq? trv 'integer))
		   (with-tmp lhs rhs mode return conf 'any
		      (lambda (left right)
			 (cond
			    ((and (number? right) (= right 0))
			     +nan.0)
			    ((m64? conf)
			     (j2s-cast `(%$$II ,left ,right)
				#f (number type) type conf))
			    ((and (inrange-int32? lhs) (inrange-int32? rhs))
			     (j2s-cast `(%$$II ,left ,right)
				#f (number type) type conf))
			    (else
			     (j2s-cast `(%$$NN ,left ,right)
				#f (number type) type conf))))))
		  ((and (eq? tl 'uint32) (eq? tr 'uint32))
		   (cond
		      ((not (uint32? right))
		       `(if (=u32 ,(asuint32 right trv) #u32:0)
			    +nan.0
			    ,(j2s-cast `(remainderu32
					   ,(asuint32 left tlv)
					   ,(asuint32 right trv))
				lhs 'uint32 type conf)))
		      ((=u32 right #u32:0)
		       +nan.0)
		      (else
		       (j2s-cast `(remainderu32
				     ,(asuint32 left tlv)
				     ,(asuint32 right trv))
			  lhs 'uint32 type conf))))
		  ((and (eq? tr 'uint32) (inrange-positive? rhs))
		   (cond
		      ((inrange-int32? rhs)
		       `(if (fixnum? ,left)
			    ,(j2s-cast `(remainderfx ,left
					   ,(asfixnum right trv))
				lhs (number type) type conf)
			    ,(if (m64? conf)
				 (j2s-cast `(%$$NZ ,(tonumber64 left tlv conf)
					       ,(tonumber64 right trv conf))
				    lhs (number type) type conf)
				 (j2s-cast `(%$$NZ ,(tonumber32 left tlv conf)
					       ,(tonumber32 right trv conf))
				    lhs (number type) type conf))))
		      ((m64? conf)
		       `(if (fixnum? ,left)
			    ,(j2s-cast `(remainderfx ,left
					   ,(asfixnum right trv))
				lhs (number type) type conf)
			    ,(j2s-cast `(%$$NZ ,(tonumber64 left tlv conf)
					   ,(tonumber64 right trv conf))
				lhs (number type) type conf)))
		      (else
		       (j2s-cast `(%$$NZ ,(tonumber32 left tlv conf)
				     ,(tonumber32 right trv conf))
			  lhs (number type) type conf))))
		  ((m64? conf)
		   (cond
		      ((and (number? right) (not (= right 0)))
		       (j2s-cast `(%$$NZ ,(tonumber64 left tlv conf)
				     ,(tonumber64 right trv conf))
			  lhs (number type) type conf))
		      ((and (type-integer? tl) (type-integer? tr))
		       (j2s-cast `(%$$II ,(tonumber64 left tlv conf)
				     ,(tonumber64 right trv conf))
			  lhs (number type) type conf))
		      (else
		       (j2s-cast `(%$$NN ,(tonumber64 left tlv conf)
				     ,(tonumber64 right trv conf))
			  lhs (number type) type conf))))
		  (else
		   (cond
		      ((and (number? right) (not (= right 0)))
		       (j2s-cast `(%$$NZ ,(tonumber32 left tlv conf)
				     ,(tonumber32 right trv conf))
			  lhs (number type) type conf))
		      ((and (type-integer? tl) (type-integer? tr)
			    (inrange-int32? lhs) (inrange-int32? rhs))
		       (j2s-cast `(%$$II ,(tonumber32 left tlv conf)
				     ,(tonumber32 right trv conf))
			  lhs (number type) type conf))
		      (else
		       (j2s-cast `(%$$NN ,(tonumber32 left tlv conf)
				     ,(tonumber32 right trv conf))
			  lhs (number type) type conf))))))))))

;*---------------------------------------------------------------------*/
;*    remainders32-minus-zero ...                                      */
;*    -------------------------------------------------------------    */
;*    -1 % -1 must produce -0.0                                        */
;*---------------------------------------------------------------------*/
(define (remainders32-minus-zero left right type lhs rhs mode return conf)
   (let ((tmp (gensym 'tmp)))
      `(if (=s32 ,right #s32:0)
	   +nan.0
	   (let ((,tmp ,(j2s-cast `(remainders32 ,left ,right)
			   lhs 'int32 type conf)))
	      (if (and (=s32 ,tmp #s32:0) (<s32 ,left #s32:0))
		  -0.0
		  ,tmp)))))

;*---------------------------------------------------------------------*/
;*    asint32 ...                                                      */
;*    -------------------------------------------------------------    */
;*    all the asXXX functions convert an expression that is statically */
;*    known to be convertible (because of the range analysis) into the */
;*    destination type.                                                */
;*---------------------------------------------------------------------*/
(define (asint32 val type::symbol)
   (case type
      ((int32) val)
      ((uint32) (if (uint32? val) (uint32->int32 val) `(uint32->int32 ,val)))
      ((int53) (if (fixnum? val) (fixnum->int32 val) `(fixnum->int32 ,val)))
      ((integer) (if (fixnum? val) (fixnum->int32 val) `(fixnum->int32 ,val)))
      ((real) (if (real? val) (flonum->int32 val) `(flonum->int32 ,val)))
      (else `(fixnum->int32 ,val))))

;*---------------------------------------------------------------------*/
;*    asuint32 ...                                                     */
;*---------------------------------------------------------------------*/
(define (asuint32 val type::symbol)
   (case type
      ((int32) (if (int32? val) (int32->uint32 val) `(int32->uint32 ,val)))
      ((uint32) val)
      ((int53) (if (fixnum? val) (fixnum->uint32 val) `(fixnum->uint32 ,val)))
      ((integer) (if (fixnum? val) (fixnum->uint32 val) `(fixnum->uint32 ,val)))
      ((real) (if (real? val) (flonum->uint32 val) `(flonum->uint32 ,val)))
      (else `(fixnum->uint32 ,val))))

;*---------------------------------------------------------------------*/
;*    asfixnum ...                                                     */
;*---------------------------------------------------------------------*/
(define (asfixnum val type::symbol)
   (case type
      ((int32) (if (int32? val) (int32->fixnum val) `(int32->fixnum ,val)))
      ((uint32) (if (uint32? val) (uint32->fixnum val) `(uint32->fixnum ,val)))
      ((real) (if (real? val) (flonum->fixnum val) `(flonum->fixnum ,val)))
      (else val)))

;*---------------------------------------------------------------------*/
;*    asreal ...                                                       */
;*---------------------------------------------------------------------*/
(define (asreal val type::symbol)
   (case type
      ((int32)
       (if (int32? val) (int32->flonum val) `(int32->flonum ,val)))
      ((uint32)
       (if (uint32? val) (uint32->flonum val) `(uint32->flonum ,val)))
      ((int53 bint)
       (if (fixnum? val) (fixnum->flonum val) `(fixnum->flonum ,val)))
      (else
       val)))

;*---------------------------------------------------------------------*/
;*    coerceint32 ...                                                  */
;*    -------------------------------------------------------------    */
;*    The coerceXXX functions are used when the range of VAL is        */
;*    known to fit the types but the static type is not known.         */
;*---------------------------------------------------------------------*/
(define (coerceint32 val type::symbol conf)
   `(if (fixnum? ,val) ,(asint32 val type) (flonum->int32 ,val)))
   
;*---------------------------------------------------------------------*/
;*    coerceuint32 ...                                                 */
;*---------------------------------------------------------------------*/
(define (coerceuint32 val type::symbol conf)
   `(if (fixnum? ,val) ,(asuint32 val type) (flonum->uint32 ,val)))

;*---------------------------------------------------------------------*/
;*    coercereal ...                                                   */
;*---------------------------------------------------------------------*/
(define (coercereal val type::symbol conf)
   `(if (fixnum? ,val) (fixnum->flonum ,val) ,val))

;*---------------------------------------------------------------------*/
;*    toflonum ...                                                     */
;*---------------------------------------------------------------------*/
(define (toflonum val type::symbol conf)
   (cond
      ((fixnum? val)
       (fixnum->flonum val))
      ((int32? val)
       (int32->flonum val))
      ((uint32? val)
       (uint32->flonum val))
      ((real? val)
       val)
      (else
       (case type
	  ((int32) `(int32->flonum ,val))
	  ((uint32) `(uint32->flonum ,val))
	  ((integer int53 bint) `(fixnum->flonum ,val))
	  ((real) val)
	  ((number) `(if (fixnum? ,val) (fixnum->flonum ,val) ,val))
	  (else (error "toflonum" "Cannot convert type" type))))))

;*---------------------------------------------------------------------*/
;*    tonumber ...                                                     */
;*---------------------------------------------------------------------*/
(define (tonumber val type::symbol conf)
   (if (m64? conf)
       (tonumber64 val type conf)
       (tonumber32 val type conf)))
       
;*---------------------------------------------------------------------*/
;*    tonumber32 ...                                                   */
;*---------------------------------------------------------------------*/
(define (tonumber32 val type::symbol conf)
   (box32 val type conf (lambda (val) `(js-tonumber ,val %this))))

;*---------------------------------------------------------------------*/
;*    toint32 ...                                                      */
;*---------------------------------------------------------------------*/
(define (toint32 val type conf)
   (case type
      ((int32)
       val)
      ((uint32)
       (if (and (uint32? val) (<u32 val (bit-lshu32 #u32:1 30)))
	   (uint32->int32 val)
	   `(uint32->int32 ,val)))
      ((int53)
       (if (fixnum? val) (fixnum->int32 val) `(fixnum->int32 ,val)))
      (else
       (if (fixnum? val)
	   (fixnum->int32 val)
	   `(if (fixnum? ,val) (fixnum->int32 ,val) (js-toint32 ,val %this))))))

;*---------------------------------------------------------------------*/
;*    touint32 ...                                                     */
;*---------------------------------------------------------------------*/
(define (touint32 val type conf)
   (case type
      ((int32)
       (if (int32? val) (int32->uint32 val) `(int32->uint32 ,val)))
      ((uint32)
       val)
      ((integer)
       (if (fixnum? val) (fixnum->uint32 val) `(fixnum->uint32 ,val)))
      ((int53)
       (if (fixnum? val) (fixnum->uint32 val) `(fixnum->uint32 ,val)))
      ((real)
       (if (flonum? val) (double->uint32 val) `(flonum->uint32 ,val)))
      (else
       (if (fixnum? val)
	   (fixnum->uint32 val)
	   `(if (fixnum? ,val) (fixnum->uint32 ,val) (js-touint32 ,val %this))))))

;*---------------------------------------------------------------------*/
;*    double->uint32 ...                                               */
;*---------------------------------------------------------------------*/
(define (double->uint32::uint32 obj::double)
   (cond
      ((or (= obj +inf.0) (= obj -inf.0) (not (= obj obj)))
       #u32:0)
      ((<fl obj 0.)
       (llong->uint32
	  (+llong (bit-lshllong #l1 32)
	     (flonum->llong (*fl -1. (floorfl (absfl obj)))))))
      (else
       (llong->uint32
	  (+llong (bit-lshllong #l1 32)
	     (flonum->llong (floorfl (absfl obj))))))))

;*---------------------------------------------------------------------*/
;*    touint32/w-overflow ...                                          */
;*---------------------------------------------------------------------*/
(define (touint32/w-overflow val type conf)
   (cond
      ((int32? val)
       (int32->uint32 val))
      ((uint32? val)
       val)
      ((fixnum? val)
       (fixnum->uint32 val))
      (else
       (case type
	  ((uint32) `(int32->uint32 ,val))
	  ((uint32) val)
	  (else (fixnum->uint32 val))))))

;*---------------------------------------------------------------------*/
;*    toint32/32 ...                                                   */
;*---------------------------------------------------------------------*/
(define (toint32/32 val type::symbol conf)
   (case type
      ((int32) val)
      ((uint32) (if (uint32? val) (uint32->int32 val) `(uint32->int32 ,val)))
      ((integer) (if (fixnum? val) (fixnum->int32 val) `(fixnum->int32 ,val)))
      (else (if (fixnum? val) (fixnum->int32 val) `(fixnum->int32 ,val)))))

;*---------------------------------------------------------------------*/
;*    tolong32 ...                                                     */
;*---------------------------------------------------------------------*/
(define (tolong32 val type::symbol conf)

   (define bit-shift32
      (-fx (config-get :int-size 30) 1))
   
   (define (int32fx? val)
      (and (>=s32 val (negs32 (bit-lshs32 #u32:1 bit-shift32)))
	   (<s32 val (bit-lshs32 #s32:1 bit-shift32))))

   (define (uint32fx? val)
      (<u32 val (bit-lshu32 #u32:1 bit-shift32)))
   
   (case type
      ((int32)
       (if (and (int32? val) (int32fx? val))
	   (int32->fixnum val)
	   `(int32->fixnum ,val)))
      ((uint32)
       (if (and (uint32? val) (uint32fx? val))
	   (uint32->fixnum val)
	   `(uint32->fixnum ,val)))
      (else val)))

;*---------------------------------------------------------------------*/
;*    tolong64 ...                                                     */
;*---------------------------------------------------------------------*/
(define (tolong64 val type::symbol conf)
   (case type
      ((int32) (if (int32? val) (int32->fixnum val) `(int32->fixnum ,val)))
      ((uint32) (if (uint32? val) (uint32->fixnum val) `(uint32->fixnum ,val)))
      (else val)))

;*---------------------------------------------------------------------*/
;*    tonumber64 ...                                                   */
;*---------------------------------------------------------------------*/
(define (tonumber64 val type::symbol conf)
   (box64 val type conf (lambda (val) `(js-tonumber ,val %this))))

;*---------------------------------------------------------------------*/
;*    todouble ...                                                     */
;*---------------------------------------------------------------------*/
(define (todouble val type::symbol conf)
   (case type
      ((int32)
       (if (int32? val) (int32->flonum val) `(int32->flonum ,val)))
      ((uint32)
       (if (uint32? val) (uint32->flonum val) `(uint32->flonum ,val)))
      ((integer bint)
       (if (fixnum? val) (fixnum->flonum val) `(fixnum->flonum ,val)))
      ((real)
       val)
      ((number)
       `(if (fixnum? ,val) (fixnum->flonum ,val) ,val))
      (else
       `(if (flonum? ,val) ,val (js-toflonum (js-tonumber ,val %this))))))

;*---------------------------------------------------------------------*/
;*    fixnums? ...                                                     */
;*---------------------------------------------------------------------*/
(define (fixnums? left tl right tr)
   (define (type-fixnum? type)
      (memq type '(int30 int53 bint)))
   
   (cond
      ((or (flonum? left) (flonum? right))
       #f)
      ((type-fixnum? tl) (if (type-fixnum? tr) #t `(fixnum? ,right)))
      ((type-fixnum? tr) `(fixnum? ,left))
      ((and (memq tl '(int53 integer number any unknown))
	    (memq tr '(int53 integer number any unknown)))
       (cond
	  ((fixnum? left)
	   (if (fixnum? right) #t `(fixnum? ,right)))
	  ((fixnum? right)
	   `(fixnum? ,left))
	  (else
	   `(fixnums? ,left ,right))))
      (else
       #f)))

;*---------------------------------------------------------------------*/
;*    if-fixnums? ...                                                  */
;*---------------------------------------------------------------------*/
(define (if-fixnums? left tl right tr then else)
   (let ((test (fixnums? left tl right tr)))
      (cond
	 ((eq? test #t) then)
	 ((eq? test #f) else)
	 (else `(if ,test ,then ,else)))))

;*---------------------------------------------------------------------*/
;*    if-fixnum? ...                                                   */
;*---------------------------------------------------------------------*/
(define (if-fixnum? left tl then else)
   (let ((test (cond
		  ((eq? tl 'integer) #t)
		  ((memq tl '(int53 number any unknown)) `(fixnum? ,left))
		  (else #f))))
      (cond
	 ((eq? test #t) then)
	 ((eq? test #f) else)
	 (else `(if ,test ,then ,else)))))

;*---------------------------------------------------------------------*/
;*    flonums? ...                                                     */
;*---------------------------------------------------------------------*/
(define (flonums? left tl right tr)

   (define (number-not-flonum? num)
      (and (number? num) (not (flonum? num))))
   
   (cond
      ((or (number-not-flonum? left) (number-not-flonum? right)) #f)
      ((eq? tl 'real) (if (eq? tr 'real) #t `(flonum? ,right)))
      ((eq? tr 'real) `(flonum? ,left))
      ((and (memq tl '(number any unknown))
	    (memq tr '(number any unknown)))
       `(and (flonum? ,left) (flonum? ,right)))
      (else #f)))

;*---------------------------------------------------------------------*/
;*    if-flonums? ...                                                  */
;*---------------------------------------------------------------------*/
(define (if-flonums? left tl right tr then else)
   (let ((test (flonums? left tl right tr)))
      (cond
	 ((eq? test #t) then)
	 ((eq? test #f) else)
	 (else `(if ,test ,then ,else)))))

;*---------------------------------------------------------------------*/
;*    if-flonum? ...                                                   */
;*---------------------------------------------------------------------*/
(define (if-flonum? left tl then else)
   (let ((test (cond
		  ((eq? tl 'real) #t)
		  ((memq tl '(number any unknown)) `(flonum? ,left))
		  (else #f))))
      (cond
	 ((eq? test #t) then)
	 ((eq? test #f) else)
	 (else `(if ,test ,then ,else)))))

;*---------------------------------------------------------------------*/
;*    binop-int32-xxx ...                                              */
;*---------------------------------------------------------------------*/
(define (binop-int32-xxx op type lhs tl left rhs tr right conf flip)
   (case tr
      ((int32)
       (binop-int32-int32 op type
	  left right flip))
      ((uint32)
       (cond
	  ((inrange-int32? rhs)
	   (binop-int32-int32 op type
	      left (asint32 right tr) flip))
	  ((inrange-uint32? lhs)
	   (binop-uint32-uint32 op type
	      (asuint32 left tl) right flip))
	  ((m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  (else
	   (case op
	      ((<)
	       `(if (<s32 ,left #s32:0)
		    ,(if flip #f #t)
		    ,(binop-uint32-xxx op type lhs 'uint32 `(int32->uint32 ,left)
			rhs tr right conf flip)))
	      (else
	       (binop-number-number op type
		  (box left tl conf) (box right tr conf) flip))))))
      ((bint)
       (if (m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip)
	   (binop-int32-int32 op type
	      left (asint32 right tr) flip)))
      ((integer)
       (cond
	  ((or (inrange-int30? rhs) (m64? conf))
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  ((inrange-int32? rhs)
	   (binop-int32-int32 op type
	      left (coerceint32 right tr conf) flip))
	  ((and (inrange-uint32? lhs) (inrange-uint32? rhs))
	   (binop-uint32-uint32 op type
	      (asuint32 left tl) (coerceuint32 right tr conf) flip))
	  (else
	   (binop-number-number op type
	      (box left tl conf) right flip))))
      ((real)
       (binop-flonum-flonum op type
	  (asreal left tl) right flip))
      ((int53)
       (binop-fixnum-fixnum op type
	  (asfixnum left tl) right flip))
      (else
       (cond
	  ((inrange-int30? rhs)
	   (binop-int32-int32 op type
	      left (asint32 right tr) flip))
	  ((inrange-int32? rhs)
	   (binop-int32-int32 op type
	      left (coerceint32 right tr conf) flip))
	  ((and (inrange-uint32? rhs) (inrange-uint32? lhs))
	   (binop-uint32-uint32 op type
	      (asuint32 left tl) (coerceuint32 right tr conf) flip))
	  ((and (inrange-uint32? rhs) (m64? conf))
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  (else
	   `(if (fixnum? ,right)
		,(binop-fixnum-fixnum op type
		    (asfixnum left tl) right flip)
		,(binop-any-any op type
		   (box left tl conf) (box right tr conf) flip)))))))

;*---------------------------------------------------------------------*/
;*    binop-uint32-xxx ...                                             */
;*---------------------------------------------------------------------*/
(define (binop-uint32-xxx op type lhs tl left rhs tr right conf flip)
   (case tr
      ((int32)
       (cond
	  ((m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  ((inrange-int32? lhs)
	   (binop-int32-int32 op type
	      (asint32 left tl) right flip))
	  ((inrange-uint32? rhs)
	   (binop-uint32-uint32 op type
	      (asint32 left tl) right flip))
	  ((inrange-uint30? lhs)
	   (binop-int32-int32 op type
	      (asint32 left tl) right flip))
	  (else
	   (if (memq op '(> >=))
	       (if flip
		   `(and (>=s32 ,right #s32:0)
			 ,(binop-uint32-uint32 op type
			     left (asuint32 right tr) flip))
		   `(or (<s32 ,right #s32:0)
			,(binop-uint32-uint32 op type
			    left (asuint32 right tr) flip)))
	       (binop-number-number op type
		  (box left tl conf) (box right tr conf) flip)))))
      ((uint32)
       (if (and (not (eq? type 'uint32))
		(inrange-int32? lhs) (inrange-int32? rhs))
	   (binop-int32-int32 op type (asint32 left tl) (asint32 right tr) flip)
	   (binop-uint32-uint32 op type left right flip)))
      ((bint)
       (cond
	  ((m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  ((inrange-int32? lhs)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) right flip))
	  ((inrange-uint32? rhs)
	   (binop-uint32-uint32 op type
	      left (asuint32 right tr) flip))
	  ((inrange-uint30? lhs)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) right flip))
	  (else
	   `(if (>=fx ,right 0)
		,(binop-uint32-uint32 op type
		    left (asuint32 right tr) flip)
		,(binop-number-number op type
		    (box left tl conf) right flip)))))
      ((integer)
       (cond
	  ((m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  ((inrange-uint32? rhs)
	   (binop-uint32-uint32 op type
	      left (coerceuint32 right tr conf) flip))
	  ((and (inrange-int32? lhs) (inrange-int32? rhs))
	   (binop-int32-int32 op type
	      (asint32 left tl) (coerceint32 right tr conf) flip))
	  ((inrange-int30? lhs)
	   (binop-bint-xxx op type lhs 'bint (asfixnum left tl)
	      rhs tr right conf flip))
	  (else
	   (binop-number-number op type
	      (box left tl conf) right flip))))
      ((real)
       (binop-flonum-flonum op type
	  (asreal left tl) right flip))
      ((int53)
       (binop-fixnum-fixnum op type
	  (asfixnum left tl) right flip))
      (else
       (cond
	  ((inrange-uint30? rhs)
	   (binop-uint32-uint32 op type
	      left (asuint32 right tr) flip))
	  ((inrange-uint32? rhs)
	   (binop-uint32-uint32 op type
	      left (coerceuint32 right tr conf) flip))
	  ((and (inrange-int32? rhs) (inrange-int32? lhs))
	   (binop-int32-int32 op type
	      (asint32 left tl) (coerceint32 right tr conf) flip))
	  ((and (inrange-int32? rhs) (m64? conf))
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  (else
	   `(if (fixnum? ,right)
		,(binop-fixnum-fixnum op type
		    (asfixnum left tl) right flip)
		,(binop-any-any op type
		    (box left tl conf) (box right tr conf) flip)))))))

;*---------------------------------------------------------------------*/
;*    binop-int53-xxx ...                                              */
;*    -------------------------------------------------------------    */
;*    Only used on 64-bit platforms.                                   */
;*---------------------------------------------------------------------*/
(define (binop-int53-xxx op type lhs tl left rhs tr right conf flip)
   (case tr
      ((int32)
       (binop-fixnum-fixnum op type left (asfixnum right tr) flip))
      ((uint32)
       (binop-fixnum-fixnum op type left (asfixnum right tr) flip))
      ((int53)
       (binop-fixnum-fixnum op type left right flip))
      (else
       `(if (fixnum? ,right)
	    ,(binop-fixnum-fixnum op type left right flip)
	    ,(if (memq type '(int32 uint32 integer bint real number))
		 (binop-number-number op type
		    (box left tl conf) (box right tr conf) flip)
		 (binop-any-any op type
		    (box left tl conf) (box right tr conf) flip))))))

;*---------------------------------------------------------------------*/
;*    binop-bint-xxx ...                                               */
;*---------------------------------------------------------------------*/
(define (binop-bint-xxx op type lhs tl left rhs tr right conf flip)
   (case tr
      ((int32)
       (binop-fixnum-fixnum op type
	  left (asfixnum right tr) flip))
      ((uint32)
       (cond
	  ((inrange-int32? rhs)
	   (binop-fixnum-fixnum op type
	      left (asfixnum right tr) flip))
	  ((inrange-uint32? lhs)
	   (binop-uint32-uint32 op type
	      (asuint32 left tl) right flip))
	  ((m64? conf)
	   (binop-fixnum-fixnum op type
	      (asfixnum left tl) (asfixnum right tr) flip))
	  (else
	   (binop-number-number op type
	      left (box right tr conf) flip))))
      ((bint)
       (binop-fixnum-fixnum op type
	  left right flip))
      ((integer)
       (if (m64? conf)
	   (binop-fixnum-fixnum op type
	      left right flip)
	   `(if (fixnum? ,right)
		,(binop-fixnum-fixnum op type
		    left right flip)
		,(binop-number-number op type
		    left right flip))))
      ((real)
       (binop-flonum-flonum op type 
	  (asreal left tl) right flip))
      (else
       (cond
	  ((inrange-int30? rhs)
	   (binop-fixnum-fixnum op type
	      left (asfixnum right tr) flip))
	  ((inrange-int32? rhs)
	   (binop-int32-int32 op type
	      (asint32 left tl) (coerceint32 right tr conf) flip))
	  ((and (inrange-uint32? rhs) (inrange-uint32? lhs))
	   (binop-uint32-uint32 op type
	      (asuint32 left tr) (coerceuint32 right tr conf) flip))
	  ((and (inrange-uint32? rhs) (m64? conf))
	   (binop-fixnum-fixnum op type
	      left (asfixnum right tr) flip))
	  (else
	   `(if (fixnum? ,right)
		,(binop-fixnum-fixnum op type
		    left right flip)
		,(if (memq type '(int32 uint32 integer bint real number))
		     (binop-number-number op type
			left (box right tr conf) flip)
		     (binop-any-any op type
			left (box right tr conf) flip))))))))

;*---------------------------------------------------------------------*/
;*    binop-integer-xxx ...                                            */
;*---------------------------------------------------------------------*/
(define (binop-integer-xxx op type lhs tl left rhs tr right conf flip)
   (if (m64? conf)
       (binop-bint-xxx op type lhs tl left rhs tr right conf flip)
       (case tr
	  ((int32)
	   `(if (fixnum? ,left)
		,(binop-fixnum-fixnum op type
		   left (asfixnum right tr) flip)
		,(binop-number-number op type
		   left (box right tr conf) flip)))
	  ((uint32)
	   (cond
	      ((inrange-int32? rhs)
	       `(if (fixnum? ,left)
		    ,(binop-int32-int32 op type
		       (asint32 left tl) (asfixnum right tr) flip)
		    ,(binop-number-number op type
		       left (box right tr conf) flip)))
	      ((inrange-uint32? lhs)
	       `(if (fixnum? ,left)
		    ,(binop-uint32-uint32 op type
		       (asuint32 left tl) right flip)
		    ,(binop-number-number op type
		       left (box right tr conf) flip)))
	      (else
	       (binop-number-number op type
		  left (box right tr conf) flip))))
	  ((bint)
	   `(if (fixnum? ,left)
		(binop-fixnum-fixnum op type
		   left right flip)
		(binop-number-number op type
		   left right flip)))
	  ((integer)
	   (if-fixnums? left tl right tr
	      (binop-fixnum-fixnum op type
		 left right flip)
	      (binop-number-number op type
		 left right flip)))
	  ((real)
	   (binop-flonum-flonum op type 
	      (coercereal left tl conf) right flip))
	  (else
	   (cond
	      ((and (inrange-int30? rhs) (inrange-int30? lhs))
	       (binop-fixnum-fixnum op type
		  (asfixnum left tl) (asfixnum right tr) flip))
	      ((and (inrange-int32? rhs) (inrange-int32? lhs))
	       (binop-int32-int32 op type
		  (coerceint32 left tl conf) (coerceint32 right tr conf) flip))
	      ((and (inrange-uint32? rhs) (inrange-uint32? lhs))
	       (binop-uint32-uint32 op type
		  (coerceuint32 left tr conf) (coerceuint32 right tr conf) flip))
	      ((and (inrange-uint32? lhs) (inrange-uint30? rhs))
	       (binop-uint32-uint32 op type
		  (coerceuint32 left tl conf) (asuint32 right tr) flip))
	      ((and (inrange-uint30? lhs) (inrange-uint32? rhs))
	       (binop-uint32-uint32 op type
		  (asuint32 left tl) (coerceuint32 right tr conf) flip))
	      (else
	       `(if (fixnum? ,right)
		    ,(binop-fixnum-fixnum op type
			left right flip)
		    ,(binop-any-any op type
			left (box right tr conf) flip))))))))

;*---------------------------------------------------------------------*/
;*    binop-real-xxx ...                                               */
;*---------------------------------------------------------------------*/
(define (binop-real-xxx op type lhs tl left rhs tr right conf flip)
   (case tr
      ((int32 uint32 bint)
       (binop-flonum-flonum op type
	  left (asreal right tr) flip))
      ((integer)
       (binop-flonum-flonum op type
	  left (coercereal right tr conf) flip))
      ((real)
       (binop-flonum-flonum op type
	  left (asreal right tr) flip))
      (else
       (if-flonum? right tr 
	  (binop-flonum-flonum op type
	     left right flip)
	  (if (memq type '(int32 uint32 integer bint real number))
	      (binop-number-number op type
		 left (box right tr conf) flip)
	      (binop-any-any op type
		 left (box right tr conf) flip))))))

;*---------------------------------------------------------------------*/
;*    binop-number-xxx ...                                             */
;*---------------------------------------------------------------------*/
(define (binop-number-xxx op type lhs tl left right tr right conf flip)
   (cond
      ((eq? tr 'number)
       (binop-number-number op type
	  left right flip))
      ((memq type '(int32 uint32 integer bint real number))
       (binop-number-number op type
	  left (box right tr conf) flip))
      (else
       (binop-any-any op type
	  left (box right tr conf) flip))))

;*---------------------------------------------------------------------*/
;*    binop-xxx-xxx ...                                                */
;*---------------------------------------------------------------------*/
(define (binop-flip op left right flip)
   (if flip `(,op ,right ,left) `(,op ,left ,right)))
   
(define (binop-int32-int32 op type left right flip)
   (let ((ops32 (cond
		   ((memq op '(== ===)) '=s32)
		   ((eq? op '<<=) '<=s32)
		   ((eq? op '>>=) '>=s32)
		   (else (symbol-append op 's32)))))
      (case type
	 ((int32)
	  (binop-flip ops32 left right flip))
	 ((uint32)
	  `(int32->uint32 ,(binop-flip ops32 left right flip)))
	 ((real)
	  (binop-flonum-flonum op type
	     (asreal left 'int32) (asreal right 'int32)
	     flip))
	 ((int53)
	  (binop-fixnum-fixnum op type
	     (asfixnum left 'int32) (asfixnum right 'int32)
	     flip))
	 ((bool)
	  (binop-flip ops32 left right flip))
	 (else
	  (binop-flip (symbol-append ops32 '/overflow) left right flip)))))
   
(define (binop-uint32-uint32 op type left right flip)
   (let ((opu32 (cond
		   ((memq op '(== ===)) '=u32)
		   ((eq? op '<<=) '<=u32)
		   ((eq? op '>>=) '>=u32)
		   (else (symbol-append op 'u32)))))
      (case type
	 ((int32)
	  `(uint32->int32 ,(binop-flip opu32 left right flip)))
	 ((uint32)
	  (binop-flip opu32 left right flip))
	 ((real)
	  (binop-flonum-flonum op type
	     (asreal left 'uint32) (asreal right 'uint32)
	     flip))
	 ((int53)
	  (binop-fixnum-fixnum op type
	     (asfixnum left 'uint32) (asfixnum right 'uint32)
	     flip))
	 ((bool)
	  (binop-flip opu32 left right flip))
	 (else
	  (binop-flip (symbol-append opu32 '/overflow) left right flip)))))
   
(define (binop-fixnum-fixnum op type left right flip)
   (let ((op (cond
		((memq op '(== ===)) '=fx)
		((eq? op '<<=) '<=fx)
		((eq? op '>>=) '>=fx)
		(else (symbol-append op 'fx)))))
      (case type
	 ((int32)
	  `(fixnum->int32 ,(binop-flip op left right flip)))
	 ((uint32)
	  `(fixnum->uint32 ,(binop-flip op left right flip)))
	 ((int53)
	  (binop-flip op left right flip))
	 ((real)
	  `(fixnum->flonum ,(binop-flip op left right flip)))
	 ((bool)
	  (binop-flip op left right flip))
	 (else
	  (binop-flip (symbol-append op '/overflow) left right flip)))))
   
(define (binop-flonum-flonum op type left right flip)
   (let ((op (if (memq op '(== ===)) '=fl (symbol-append op 'fl))))
      (case type
	 ((int32)
	  `(flonum->int32 ,(binop-flip op left right flip)))
	 ((uint32)
	  `(flonum->uint32 ,(binop-flip op left right flip)))
	 ((bool)
	  (binop-flip op left right flip))
	 (else
	  (binop-flip op left right flip)))))
   
(define (binop-number-number op type left right flip)
   (let ((op (if (memq op '(== ===)) '= op)))
      (case type
	 ((bool)
	  (binop-flip op left right flip))
	 ((int32)
	  `(js-number-toint32
	      ,(binop-flip (symbol-append op '/overflow) left right flip)))
	 ((uint32)
	  `(js-number-touint32
	      ,(binop-flip (symbol-append op '/overflow) left right flip)))
	 ((real)
	  `(js-toflonum
	      ,(binop-flip (symbol-append op '/overflow) left right flip)))
	 (else
	  (binop-flip (symbol-append op '/overflow) left right flip)))))
   
(define (binop-any-any op type left right flip)
   (case op
      ((===)
       (if flip
	   `(js-strict-equal? ,right ,left)
	   `(js-strict-equal? ,left ,right)))
      ((js-strict-equal-no-string?)
       (if flip
	   `(js-strict-equal-no-string? ,right ,left)
	   `(js-strict-equal-no-string? ,left ,right)))
      (else
       (let ((op (cond 
		    ((eq? op '==) 'js-equal?)
		    ((memq type '(integer number bool)) (symbol-append op 'js))
		    (else (symbol-append 'js op)))))
	  (case type
	     ((bool)
	      (if flip
		  `(,op ,right ,left %this)
		  `(,op ,left ,right %this)))
	     ((int32)
	      `(js-number-toint32
		  ,(if flip
		       `(,op ,right ,left %this)
		       `(,op ,left ,right %this))))
	     ((uint32)
	      `(js-number-touint32
		  ,(if flip
		       `(,op ,right ,left %this)
		       `(,op ,left ,right %this))))
	     ((real)
	      `(js-toflonum
		  ,(if flip
		       `(,op ,right ,left %this)
		       `(,op ,left ,right %this))))
	     (else
	      (if flip
		  `(,op ,right ,left %this)
		  `(,op ,left ,right %this))))))))

   
