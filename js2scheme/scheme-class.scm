;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/scheme-class.scm          */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Mon Aug 21 07:01:46 2017                          */
;*    Last change :  Sat Apr  6 07:17:22 2019 (serrano)                */
;*    Copyright   :  2017-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    ES2015 Scheme class generation                                   */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_scheme-class

   (include "ast.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_js
	   __js2scheme_stmtassign
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_scheme
	   __js2scheme_scheme-fun
	   __js2scheme_scheme-utils)

   (export (j2s-scheme-super ::J2SCall mode return conf)))

;*---------------------------------------------------------------------*/
;*    j2s-scheme ::J2SDeclClass ...                                    */
;*---------------------------------------------------------------------*/
(define-method (j2s-scheme this::J2SDeclClass mode return conf)
   "declclass not implemented yet")

;*---------------------------------------------------------------------*/
;*    j2s-scheme ::J2SClass ...                                        */
;*---------------------------------------------------------------------*/
(define-method (j2s-scheme this::J2SClass mode return conf)
   
   (define (constructor? prop::J2SDataPropertyInit)
      (with-access::J2SDataPropertyInit prop (name)
	 (let loop ((name name))
	    (cond
	       ((isa? name J2SLiteralCnst)
		(with-access::J2SLiteralCnst name (val)
		   (loop val)))
	       ((isa? name J2SLiteralValue)
		(with-access::J2SLiteralValue name (val)
		   (equal? val "constructor")))))))
   
   (define (find-constructor elements)
      (find (lambda (m)
	       (with-access::J2SClassElement m (prop static)
		  (unless static
		     (when (isa? prop J2SDataPropertyInit)
			(constructor? prop)))))
	 elements))
   
   (define (j2s-propname name)
      (cond
	 ((isa? name J2SString)
	  (with-access::J2SString name (val)
	     (let ((str (string-for-read val)))
		`(& ,val))))
	 ((isa? name J2SNumber)
	  (with-access::J2SNumber name (val)
	     (if (fixnum? val)
		 `(js-integer-name->jsstring ,val)
		 `(js-toname ,(j2s-scheme val mode return conf) %this))))
	 ((isa? name J2SPragma)
	  `(js-toname ,(j2s-scheme name mode return conf) %this))
	 ((isa? name J2SLiteralCnst)
	  `(js-toname ,(j2s-scheme name mode return conf) %this))
	 ((isa? name J2SLiteralValue)
	  (with-access::J2SLiteralValue name (val)
	     `(js-toname ,(j2s-scheme val mode return conf) %this)))
	 (else
	  `(js-toname ,(j2s-scheme name mode return conf) %this))))
   
   (define (bind-class-method obj prop)
      (cond
	 ((isa? prop J2SDataPropertyInit)
	  (with-access::J2SDataPropertyInit prop (name val)
	     (unless (constructor? prop)
		`(js-bind! %this ,obj ,(j2s-propname name)
		    :value ,(j2s-scheme val mode return conf)
		    :writable #t :enumerable #f :configurable #t))))
	 ((isa? prop J2SAccessorPropertyInit)
	  (with-access::J2SAccessorPropertyInit prop (name get set)
	     `(js-bind! %this ,obj ,(j2s-propname name)
		 :get ,(when get
			  (j2s-scheme get mode return conf))
		 :set ,(when set
			  (j2s-scheme set mode return conf))
		 :writable #t :enumerable #f :configurable #t)))
	 (else
	  #f)))
   
   (define (bind-static clazz m)
      (with-access::J2SClassElement m (prop static)
	 (when static
	    (bind-class-method clazz prop))))
   
   (define (bind-method proto m)
      (with-access::J2SClassElement m (prop static)
	 (when (not static)
	    (bind-class-method proto prop))))
   
   (define (let-super super proc)
      (cond
	 ((isa? super J2SUndefined)
	  (proc #f))
	 ((isa? super J2SNull)
	  (proc '()))
	 (else
	  (let ((superid (gensym 'super)))
	     `(let* ((,superid ,(j2s-scheme super mode return conf))
		     (%super (js-get ,superid 'prototype %this))
		     (%superctor ,superid))
		 ,(proc superid))))))
   
   (define (make-class name super els constructor arity length ctorsz src loc)
      (let* ((cname (or name (gensym 'class)))
	     (clazz (symbol-append cname '%CLASS))
	     (ctor (symbol-append cname '%CTOR))
	     (proto (symbol-append cname '%PROTOTYPE)))
	 `(letrec* ((,ctor ,constructor)
		    (,proto ,(cond
				((eq? super #f)
				 `(with-access::JsGlobalObject %this (js-object)
				     (js-new0 %this js-object)))
				((null? super)
				 `(with-access::JsGlobalObject %this (js-object)
				     (let ((o (js-new0 %this js-object)))
					(with-access::JsObject o (__proto__)
					   (set! __proto__ '())
					   o))))
				(else
				 `(js-new-sans-construct %this ,super))))
		    (,clazz (js-make-function %this
			       ,ctor
			       ,length
			       ,(symbol->string! cname)
			       :src ,(when src (class-src loc this conf))
			       :strict ',mode
			       :alloc ,(if (or (eq? super #f) (null? super))
					   'js-object-alloc/new-target
					   `(with-access::JsFunction ,super (alloc) alloc))
			       :prototype  ,proto
			       :arity ,arity
			       :__proto__ ,(if (null? super)
					       '(with-access::JsGlobalObject %this (js-function-prototype)
						 js-function-prototype)
					       super)
			       :constrsize ,ctorsz))
		    ,@(if name `((,(j2s-fast-id name) (js-make-let))) '()))
	     ,@(filter-map (lambda (m) (bind-static clazz m)) els)
	     ,@(filter-map (lambda (m) (bind-method proto m)) els)
	     ,@(if name `((set! ,(j2s-fast-id name) ,clazz)) '())
	     ,clazz)))
   
   (with-access::J2SClass this (super elements name src loc decl)
      (let ((ctor (find-constructor elements)))
	 (when decl
	    (with-access::J2SDecl decl (_scmid)
	       (set! _scmid (j2s-fast-id name))))
	 (let-super super
	    (lambda (super)
	       (cond
		  (ctor
		   (with-access::J2SClassElement ctor (prop)
		      (with-access::J2SDataPropertyInit prop (val)
			 (with-access::J2SFun val (constrsize params thisp)
			    (make-class name super elements
			       (ctor->lambda val name mode return conf #f #t super)
			       (+fx 1 (length params))
			       (length params) constrsize
			       src loc)))))
		  (super
		   (make-class name super elements
		      `(lambda (this . args)
			(let ((%nothis this))
			   (js-apply %this %superctor this args)
			   (set! this %nothis)
			   (js-undefined)))
		      `(with-access::JsFunction %superctor (arity) arity)
		      0 0 src loc))
		  (else
		   (make-class name super elements
		      `(lambda (this)
			  (with-access::JsGlobalObject %this (js-new-target)
			     (if (eq? js-new-target (js-undefined))
				 (js-raise-type-error/loc %this ',loc
				    (format
				       "Class constructor '~a' cannot be invoked without 'new'"
				       ',name)
				    (js-undefined))
				 (begin
				    (set! js-new-target (js-undefined))
				    this))))
		      1 0 0 src loc))))))))

;*---------------------------------------------------------------------*/
;*    ctor-check-instance ...                                          */
;*---------------------------------------------------------------------*/
(define (ctor-check-instance name new-target body loc)
   
   (define (err name loc)
      (J2SStmtExpr
	 (J2SPragma
	    `(js-raise-type-error/loc %this ',loc
		,(format
		    "Class constructor '~a' cannot be invoked without 'new'"
		    name)
		(js-undefined)))))
   
   (cond
      ((isa? body J2SLetBlock)
       (with-access::J2SLetBlock body (nodes loc)
	  (set! nodes
	     (list
		(J2SIf (J2SPragma/type 'bool '(eq? new-target (js-undefined)))
		   (err name loc)
		   (J2SSeq* nodes))))
	  body))
       (raise
	  (instantiate::&io-parse-error
	     (proc "internal error (scheme-class)")
	     (msg "body should be a J2SLetBlock")
	     (obj (j2s->list body))
	     (fname (cadr loc))
	     (location (caddr loc))))))
   
;*---------------------------------------------------------------------*/
;*    ctor->lambda ...                                                 */
;*---------------------------------------------------------------------*/
(define (ctor->lambda val::J2SFun name mode return conf proto ctor-only super)

   (define (check-body-instance body)
      (with-access::J2SFun val (new-target loc)
	 (ctor-check-instance name new-target body loc)))
   
   (define (unthis this loc)
      (instantiate::J2SStmtExpr
	 (loc loc)
	 (expr (instantiate::J2SPragma
		  (loc loc)
		  (expr `(set! ,this (js-make-let)))))))
   
   (define (returnthis this loc)
      (J2SStmtExpr (J2SRef this)))
   
   (with-access::J2SFun val (body idthis loc thisp loc)
      (with-access::J2SBlock body (loc endloc nodes)
	 (cond
	    ((and (symbol? super) (need-super-check? val))
	     (when (> (bigloo-warning) 1)
		(warning/loc loc "Forced super check in constructor"))
	     (let* ((thisp-safe (duplicate::J2SDecl thisp (binder 'let-opt)))
		    (decl (J2SLetOpt '(ref) '%nothis (J2SThis thisp-safe))))
		(with-access::J2SDecl thisp (binder)
		   (set! binder 'let))
		(with-access::J2SDecl decl (_scmid)
		   (set! _scmid '%nothis))
		(set! body
		   (instantiate::J2SLetBlock
		      (loc loc)
		      (endloc endloc)
		      (decls (list decl))
		      (nodes (list (unthis idthis loc)
				(J2STry
				   (J2SBlock (check-body-instance body))
				   (J2SNop)
				   (returnthis thisp loc))))))))
	    ((symbol? super)
	     (let ((decl (J2SLetOpt '(ref) '%nothis (J2SThis thisp))))
		(with-access::J2SDecl decl (_scmid)
		   (set! _scmid '%nothis))
		(set! body
		   (instantiate::J2SLetBlock
		      (loc loc)
		      (endloc endloc)
		      (decls (list decl))
		      (nodes (list (check-body-instance body)))))))
	    (else
	     (set! body (J2SBlock (check-body-instance body)))))))
   
      (jsfun->lambda val mode return conf proto ctor-only))

;*---------------------------------------------------------------------*/
;*    class-src ...                                                    */
;*---------------------------------------------------------------------*/
(define (class-src loc val::J2SClass conf)
   (with-access::J2SClass val (src loc endloc)
      (when src
	 (match-case loc
	    ((at ?path ?start)
	     (let ((m (config-get-mmap conf path)))
		`'(,loc . ,(when (mmap? m)
			      (match-case endloc
				 ((at ?file ?end)
				  (when (and (string=? (mmap-name m) file)
					     (string=? path file)
					     (<fx start end)
					     (>=fx start 0)
					     (<fx end (mmap-length m)))
				     (mmap-substring m
					(fixnum->elong start)
					(+elong 1 (fixnum->elong end))))))))))))))

;*---------------------------------------------------------------------*/
;*    j2s-scheme-super ...                                             */
;*---------------------------------------------------------------------*/
(define (j2s-scheme-super this::J2SCall mode return conf)
   (with-access::J2SCall this (loc fun this args protocol cache)
      (let* ((len (length args))
	     (call (if (>=fx len 11)
		       'js-calln
		       (string->symbol (format "js-call~a" len))))
	     (ctor (gensym 'ctor))
	     (tmp (gensym 'tmp)))
	 `(with-access::JsGlobalObject %this (js-new-target)
	     (set! js-new-target new-target)
	     (let ((,tmp (,call ,j2s-unresolved-call-workspace
			    %superctor
			    %nothis
			    ,@(j2s-scheme args mode return conf))))
		(set! this %nothis)
		,tmp)))))
   
;*---------------------------------------------------------------------*/
;*    need-super-check? ...                                            */
;*    -------------------------------------------------------------    */
;*    A constructor needs a super check, if it cannot be proved        */
;*    statically that                                                  */
;*      1) it always calls the super constructor                       */
;*      2) the call the super preceeds all "this" accesses             */
;*---------------------------------------------------------------------*/
(define (need-super-check? val::J2SFun)
   (with-access::J2SFun val (body)
      (not (eq? (super-call body) #t))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SNode ...                                         */
;*---------------------------------------------------------------------*/
(define-generic (super-call this::J2SNode)
   #f)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SExpr ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SExpr)
   #f)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SUnary ...                                        */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SUnary)
   (with-access::J2SUnary this (expr)
      (super-call expr)))
   
;*---------------------------------------------------------------------*/
;*    super-call ::J2SBinary ...                                       */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SBinary)
   (with-access::J2SBinary this (lhs rhs)
      (let ((l (super-call lhs)))
	 (cond
	    ((eq? l #t) #t)
	    ((eq? l #unspecified) (super-call rhs))
	    (else #f)))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SAssig ...                                        */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SAssig)
   (with-access::J2SAssig this (lhs rhs)
      (let ((r (super-call rhs)))
	 (cond
	    ((not r) #f)
	    ((eq? r #unspecified) (super-call lhs))
	    (else #t)))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SLiteral ...                                      */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SLiteral)
   #unspecified)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SRef ...                                          */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SRef)
   #unspecified)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SThis ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SThis)
   #f)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SAccess ...                                       */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SAccess)
   (with-access::J2SAccess this (obj field)
      (let ((f (super-call field)))
	 (cond
	    ((eq? f #t) #t)
	    ((eq? f #unspecified) (super-call obj))
	    (else #f)))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SCall ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SCall)
   (with-access::J2SCall this (fun args)
      (when (every super-call args)
	 (or (every (lambda (a) (eq? (super-call a) #t)) args)
	     (isa? fun J2SSuper)
	     (super-call fun)))))

;*---------------------------------------------------------------------*/
;*    super-call-cond ...                                              */
;*---------------------------------------------------------------------*/
(define (super-call-cond test then else)
   (let ((t (super-call test)))
      (cond
	 ((eq? t #t)
	  t)
	 ((eq? t #unspecified)
	  (let ((t (super-call then))
		(e (super-call else)))
	     (cond
		((or (not t) (not e)) #f)
		((and (eq? t #t) (eq? e #t)) #t)
		(else #unspecified))))
	 (else
	  #f))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SIf ...                                           */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SIf)
   (with-access::J2SIf this (test then else)
      (super-call-cond test then else)))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SStmt ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SStmt)
   #f)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SStmtExpr ...                                     */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SStmtExpr)
   (with-access::J2SStmtExpr this (expr)
      (super-call expr)))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SCond ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SCond)
   (with-access::J2SCond this (test then else)
      (super-call-cond test then else)))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SSeq ...                                          */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SSeq)
   (with-access::J2SSeq this (nodes)
      (let loop ((nodes nodes))
	 (if (null? nodes)
	     #unspecified
	     (let ((s (super-call (car nodes))))
		(cond
		   ((not s) #f)
		   ((eq? s #unspecified) (loop (cdr nodes)))
		   (else #t)))))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SLetBlock ...                                     */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SLetBlock)
   (with-access::J2SLetBlock this (decls)
      (let loop ((decls decls))
	 (if (null? decls)
	     (call-next-method)
	     (let ((s (super-call (car decls))))
		(cond
		   ((not s) #f)
		   ((eq? s #unspecified) (loop (cdr decls)))
		   (else #t)))))))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SDecl ...                                         */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SDecl)
   #unspecified)

;*---------------------------------------------------------------------*/
;*    super-call ::J2SDeclInit ...                                     */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SDeclInit)
   (with-access::J2SDeclInit this (val)
      (super-call val)))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SReturn ...                                       */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SReturn)
   (with-access::J2SReturn this (expr)
      (super-call expr)))

;*---------------------------------------------------------------------*/
;*    super-call ::J2SPragma ...                                       */
;*---------------------------------------------------------------------*/
(define-method (super-call this::J2SPragma)
   #unspecified)
