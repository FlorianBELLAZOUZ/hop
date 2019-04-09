;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/scheme-utils.scm          */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Mon Aug 21 07:06:27 2017                          */
;*    Last change :  Tue Apr  9 17:23:06 2019 (serrano)                */
;*    Copyright   :  2017-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Utility functions for Scheme code generation                     */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_scheme-utils
   
   (include "ast.sch")
   
   (import __js2scheme_ast
	   __js2scheme_dump
	   __js2scheme_utils
	   __js2scheme_js
	   __js2scheme_stmtassign
	   __js2scheme_compile
	   __js2scheme_stage
	   __js2scheme_scheme-cast)
   
   (export j2s-unresolved-put-workspace
           j2s-unresolved-del-workspace
	   j2s-unresolved-get-workspace
	   j2s-unresolved-call-workspace

	   (loc->point::long ::obj)
	   
	   (epairify loc expr)
	   (epairify-deep loc expr)
	   (strict-mode? mode)
	   (j2s-fast-id id)
	   (j2s-fast-constructor-id id)
	   (j2s-scheme-id id pref)
	   (j2s-scheme-name ::symbol)
	   (j2s-decl-scheme-id ::J2SDecl)
	   (js-need-global? ::J2SDecl scope mode)
	   (flatten-stmt stmt)
	   (flatten-nodes nodes)
	   (flatten-begin nodes)
	   (remove-undefined lst)
	   (j2s-this-cache? ::J2SDecl)
	   (j2s-minlen val)
	   
	   (typeof-this obj conf)
	   (maybe-number? expr::J2SNode)
	   (mightbe-number?::bool field::J2SExpr)
	   
	   (utype-ident ident utype conf #!optional compound)
	   (vtype-ident ident vtype conf #!optional compound)
	   (type-ident ident type conf)
	   (j2s-number val conf)
	   (j2s-error proc msg obj #!optional str)
	   (is-fixnum? expr::J2SExpr conf)
	   (is-number? expr::J2SExpr)
	   (is-integer? expr::J2SExpr)
	   (is-int30? expr::J2SExpr)
	   (is-int53? expr::J2SExpr)
	   (is-fx? expr::J2SExpr)
	   (is-uint32? expr::J2SExpr)
	   (is-uint53? expr::J2SExpr)
	   (is-string? expr::J2SExpr)

	   (j2s-jsstring val loc)
	   (j2s-string->jsstring ::bstring)
	   
	   (j2s-unresolved name throw cache loc)
	   (js-not expr)
	   
	   (js-pcache cache)
	   
	   (j2s-get loc obj field tyobj prop typrop tyval conf cache optimp
	      #!optional (cspecs '(cmap pmap amap vtable)))
	   (j2s-put! loc obj field tyobj prop typrop val tyval mode conf
	      cache optimp
	      #!optional (cspecs '(cmap pmap amap vtable)))

	   (inrange-positive?::bool ::J2SExpr)
	   (inrange-positive-number?::bool ::J2SExpr)
	   (inrange-one?::bool ::J2SExpr)
	   (inrange-32?::bool ::J2SExpr)
	   (inrange-int30?::bool ::J2SExpr)
	   (inrange-uint30?::bool ::J2SExpr)
	   (inrange-int32?::bool ::J2SExpr)
	   (inrange-uint32?::bool ::J2SExpr)
	   (inrange-uint32-number?::bool ::J2SExpr)
	   (inrange-int53?::bool ::J2SExpr)

	   (box ::obj ::symbol ::pair-nil #!optional proc::obj)
	   (box32 ::obj ::symbol ::pair-nil  #!optional proc::obj)
	   (box64 ::obj ::symbol ::pair-nil #!optional proc::obj)

	   (expr-asuint32 expr::J2SExpr)
	   (uncast::J2SExpr ::J2SExpr)

	   (cancall?::bool ::J2SNode)
	   (optimized-ctor ::J2SNode)))

;*---------------------------------------------------------------------*/
;*    j2s-unresolved-workspaces ...                                    */
;*---------------------------------------------------------------------*/
(define j2s-unresolved-put-workspace '%this)
(define j2s-unresolved-del-workspace '%this)
(define j2s-unresolved-get-workspace '%scope)
(define j2s-unresolved-call-workspace '%this)

;*---------------------------------------------------------------------*/
;*    loc->point ...                                                   */
;*---------------------------------------------------------------------*/
(define (loc->point loc)
   (match-case loc
      ((at ?- ?point) point)
      (else -1)))

;*---------------------------------------------------------------------*/
;*    epairify ...                                                     */
;*---------------------------------------------------------------------*/
(define (epairify loc expr)
   (if (pair? expr)
       (econs (car expr) (cdr expr) loc)
       expr))

;*---------------------------------------------------------------------*/
;*    epairify-deep ...                                                */
;*---------------------------------------------------------------------*/
(define (epairify-deep loc expr)
   (if (or (epair? expr) (not (pair? expr)))
       expr
       (econs (epairify-deep loc (car expr))
	  (epairify-deep loc (cdr expr))
	  loc)))

;*---------------------------------------------------------------------*/
;*    strict-mode? ...                                                 */
;*---------------------------------------------------------------------*/
(define (strict-mode? mode)
   (or (eq? mode 'strict) (eq? mode 'hopscript)))

;*---------------------------------------------------------------------*/
;*    j2s-fast-id ...                                                  */
;*---------------------------------------------------------------------*/
(define (j2s-fast-id id)
   (if (eq? id '||)
       '@_
       (symbol-append '@ id)))

;*---------------------------------------------------------------------*/
;*    j2s-fast-constructor-id ...                                      */
;*---------------------------------------------------------------------*/
(define (j2s-fast-constructor-id id)
   (symbol-append '@new- id))

;*---------------------------------------------------------------------*/
;*    j2s-scheme-id ...                                                */
;*---------------------------------------------------------------------*/
(define (j2s-scheme-id id pref)
   (cond
      ((char=? (string-ref (symbol->string! id) 0) #\%) id)
      ((memq id '(GLOBAL global arguments)) id)
      (else (symbol-append pref id))))

;*---------------------------------------------------------------------*/
;*    j2s-scheme-name ...                                              */
;*---------------------------------------------------------------------*/
(define (j2s-scheme-name id)
   `(& ,(symbol->string! id)))
   
;*---------------------------------------------------------------------*/
;*    j2s-decl-scheme-id ...                                           */
;*---------------------------------------------------------------------*/
(define (j2s-decl-scheme-id decl::J2SDecl)
   (with-access::J2SDecl decl (_scmid id scope key)
      (if _scmid
	  _scmid
	  (let ((sid (j2s-scheme-id id (if (eq? scope '%scope) '! '^))))
	     (set! _scmid sid)
	     sid))))

;*---------------------------------------------------------------------*/
;*    js-need-global? ...                                              */
;*---------------------------------------------------------------------*/
(define (js-need-global? decl::J2SDecl scope mode)
   (with-access::J2SDecl decl (usage)
      (or (not (j2s-let-opt? decl))
	  (memq 'eval usage)
	  (not (and (eq? scope '%scope) (eq? mode 'hopscript))))))

;*---------------------------------------------------------------------*/
;*    flatten-begin ...                                                */
;*---------------------------------------------------------------------*/
(define (flatten-begin nodes)
   (cond
      ((null? nodes) `(js-undefined))
      ((null? (cdr nodes)) (car nodes))
      (else `(begin ,@(remove-undefined (flatten-nodes nodes))))))

;*---------------------------------------------------------------------*/
;*    flatten-stmt ...                                                 */
;*---------------------------------------------------------------------*/
(define (flatten-stmt stmt)
   (when (and (pair? stmt) (eq? (car stmt) 'begin))
      (set-cdr! stmt (flatten-nodes (cdr stmt))))
   stmt)

;*---------------------------------------------------------------------*/
;*    flatten-nodes ...                                                */
;*---------------------------------------------------------------------*/
(define (flatten-nodes nodes)
   (append-map
      (lambda (l)
	 (if (and (pair? l) (eq? (car l) 'begin))
	     (flatten-nodes (cdr l))
	     (list l)))
      nodes))

;*---------------------------------------------------------------------*/
;*    remove-undefined ...                                             */
;*---------------------------------------------------------------------*/
(define (remove-undefined lst)
   (cond
      ((or (null? lst) (null? (cdr lst)))
       lst)
      ((equal? (car lst) '(js-undefined))
       (remove-undefined (cdr lst)))
      (else
       (let loop ((prev lst)
		  (run (cdr lst)))
	  (cond
	     ((or (null? run) (null? (cdr run)))
	      lst)
	     ((equal? (car run) '(js-undefined))
	      (set-cdr! prev (cdr run))
	      (loop prev (cdr run)))
	     (else
	      (loop run (cdr run))))))))

;*---------------------------------------------------------------------*/
;*    j2s-this-cache? ...                                              */
;*---------------------------------------------------------------------*/
(define (j2s-this-cache? this::J2SDecl)
   (with-access::J2SDecl this (usage usecnt)
      (and (>=fx usecnt 3)
	   (not (memq 'ref usage))
	   (not (memq 'call usage))
	   (not (memq 'new usage)))))

;*---------------------------------------------------------------------*/
;*    j2s-minlen ...                                                   */
;*---------------------------------------------------------------------*/
(define (j2s-minlen val)
   (with-access::J2SFun val (params vararg name)
      (let ((len 0))
	 (for-each (lambda (p)
		      (when (or (not (isa? p J2SDeclInit))
				(with-access::J2SDeclInit p (val)
				   (nodefval? val)))
			 (set! len (+fx len 1))))
	    params)
	 (if (eq? vararg 'rest)
	     (-fx len 1)
	     len))))

;*---------------------------------------------------------------------*/
;*    typeof-this ...                                                  */
;*---------------------------------------------------------------------*/
(define (typeof-this obj conf)
   (let ((ty (j2s-type obj)))
      (if (not (memq ty '(any unknown)))
	  ty
	  (let ((tyv (j2s-vtype obj)))
	     (if (eq? tyv 'object)
		 (if (and (isa? obj J2SThis)
			  (with-access::J2SThis obj (decl)
			     (with-access::J2SDecl decl (vtype)
				(eq? vtype 'this))))
		     'this
		     tyv)
		 tyv)))))

;*---------------------------------------------------------------------*/
;*    maybe-number? ...                                                */
;*---------------------------------------------------------------------*/
(define (maybe-number? expr::J2SNode)
   (memq (j2s-vtype expr) '(any int32 uint32 int53 integer number real)))

;*---------------------------------------------------------------------*/
;*    mightbe-number? ...                                              */
;*---------------------------------------------------------------------*/
(define (mightbe-number?::bool field::J2SExpr)
   (or (is-number? field)
       (with-access::J2SExpr field (hint)
	  (or (assq 'index hint) (assq 'number hint) (assq 'integer hint)))
       (when (isa? field J2SBinary)
	  (with-access::J2SBinary field (lhs rhs op)
	     (when (eq? op '+)
		(or (mightbe-number? lhs) (mightbe-number? rhs)))))
       (when (eq? (j2s-type field) 'any)
	  (or (isa? field J2SPostfix) (isa? field J2SPrefix)))))

;*---------------------------------------------------------------------*/
;*    utype-ident ...                                                  */
;*---------------------------------------------------------------------*/
(define (utype-ident ident utype conf #!optional compound)
   (cond
      ((or (eq? utype 'any) (eq? utype 'unknown))
       ident)
      (compound
       (symbol-append ident '|::| (type-name utype conf)))
      (else
       ident)))

;*---------------------------------------------------------------------*/
;*    vtype-ident ...                                                  */
;*---------------------------------------------------------------------*/
(define (vtype-ident ident utype conf #!optional compound)
   (cond
      ((or (eq? utype 'any) (eq? utype 'unknown))
       ident)
      (compound
       (symbol-append ident '|::| (type-name utype conf)))
      (else
       ident)))

;*---------------------------------------------------------------------*/
;*    type-ident ...                                                   */
;*---------------------------------------------------------------------*/
(define (type-ident ident type conf)
   (cond
      ((memq type '(int32 uint32)) (symbol-append ident '|::| type))
      ((memq type '(bint)) (symbol-append ident '|::bint|))
      ((eq? type 'any) (symbol-append ident '|::obj|))
      ((type-name type conf)
       =>
       (lambda (tname) (symbol-append ident '|::| tname)))
      (else ident)))

;*---------------------------------------------------------------------*/
;*    j2s-number ...                                                   */
;*---------------------------------------------------------------------*/
(define (j2s-number val conf)
   (cond
      ((elong? val)
       (cond
	  ((and (>=elong val (-elong #e0 (bit-lshelong #e1 29)))
		(<=elong val (bit-lshelong #e1 29)))
	   (elong->fixnum val))
	  ((>=fx (config-get conf :int-size 0) 32)
	   (cond-expand
	      (bint30 `(elong->fixnum ,val))
	      (else (elong->fixnum val))))
	  (else
	   (elong->flonum val))))
      ((llong? val)
       (cond
	  ((and (>=llong val (-llong #l0 (bit-lshllong #l1 29)))
		(<=llong val (bit-lshllong #l1 29)))
	   (llong->fixnum val))
	  ((and (>=fx (config-get conf :int-size 0) 53)
		(>=llong val (-llong #l0 (bit-lshllong #l1 53)))
		(<=llong val (bit-lshllong #l1 53)))
	   (cond-expand
	      ((or bint30 bint32)
	       `(llong->fixnum ,val))
	      (else
	       (llong->fixnum val))))
	  (else
	   (llong->flonum val))))
      ((bignum? val)
       (bignum->flonum val))
      ((fixnum? val)
       (cond-expand
	  ((or bint30 bint32)
	   val)
	  ((or bint61 62 64)
	   (cond
	      ((and (>=fx (config-get conf :int-size 0) 53)
		    (<fx val (bit-lsh 1 53))
		    (>fx val (negfx (bit-lsh 1 53))))
	       val)
	      ((and (<fx val (-fx (bit-lsh 1 29) 1))
		    (>=fx val (negfx (bit-lsh 1 29))))
	       val)
	      (else
	       (fixnum->flonum val))))
	  (else
	   (error "j2s-scheme" "unknown integer size"
	      (config-get conf :int-size (bigloo-config 'int-size))))))
      (else val)))

;*---------------------------------------------------------------------*/
;*    j2s-error ...                                                    */
;*---------------------------------------------------------------------*/
(define (j2s-error proc msg obj #!optional str)
   (with-access::J2SNode obj (loc)
      (match-case loc
	 ((at ?fname ?loc)
	  (error/location proc msg (or str (j2s->list obj)) fname loc))
	 (else
	  (error proc msg obj)))))

;*---------------------------------------------------------------------*/
;*    is-number? ...                                                   */
;*---------------------------------------------------------------------*/
(define (is-number? expr::J2SExpr)
   (type-number? (j2s-type expr)))

;*---------------------------------------------------------------------*/
;*    is-integer? ...                                                  */
;*---------------------------------------------------------------------*/
(define (is-integer? expr::J2SExpr)
   (type-integer? (j2s-vtype expr)))

;*---------------------------------------------------------------------*/
;*    is-int30? ...                                                    */
;*---------------------------------------------------------------------*/
(define (is-int30? expr::J2SExpr)
   (type-int30? (j2s-vtype expr)))

;*---------------------------------------------------------------------*/
;*    is-int53? ...                                                    */
;*---------------------------------------------------------------------*/
(define (is-int53? expr::J2SExpr)
   (let ((ty (j2s-vtype expr)))
      (or (type-int53? ty) (eq? ty 'ufixnum))))

;*---------------------------------------------------------------------*/
;*    is-fx? ...                                                       */
;*---------------------------------------------------------------------*/
(define (is-fx? expr::J2SExpr)
   (type-fixnum? (j2s-vtype expr)))

;*---------------------------------------------------------------------*/
;*    is-fixnum? ...                                                   */
;*---------------------------------------------------------------------*/
(define (is-fixnum? expr::J2SExpr conf)
   (if (m64? conf)
       (or (type-integer? (j2s-vtype expr)) (type-int53? (j2s-vtype expr)))
       (or (type-int30? (j2s-vtype expr)) (eq? (j2s-vtype expr) 'ufixnum))))

;*---------------------------------------------------------------------*/
;*    is-uint32? ...                                                   */
;*---------------------------------------------------------------------*/
(define (is-uint32? expr::J2SExpr)
   (type-uint32? (j2s-vtype expr)))

;*---------------------------------------------------------------------*/
;*    is-uint53? ...                                                   */
;*---------------------------------------------------------------------*/
(define (is-uint53? expr::J2SExpr)
   (let ((ty (j2s-vtype expr)))
      (or (type-int53? ty) (eq? ty 'ufixnum))))

;*---------------------------------------------------------------------*/
;*    is-string? ...                                                   */
;*---------------------------------------------------------------------*/
(define (is-string? expr::J2SExpr)
   (eq? (j2s-vtype expr) 'string))

;*---------------------------------------------------------------------*/
;*    j2s-jsstring ...                                                 */
;*---------------------------------------------------------------------*/
(define (j2s-jsstring val loc)
   (epairify loc (j2s-string->jsstring val)))

;*---------------------------------------------------------------------*/
;*    j2s-unresolved ...                                               */
;*---------------------------------------------------------------------*/
(define (j2s-unresolved name throw cache loc)
   (cond
      ((eq? name 'undefined)
       `(js-undefined))
      (cache
       `(js-global-object-get-name/cache ,j2s-unresolved-get-workspace
	   (& ,(symbol->string name))
	   ,(if (pair? throw) `',throw throw)
	   %this
	   ,(js-pcache cache) ,(loc->point loc)))
      (else
       `(js-global-object-get-name ,j2s-unresolved-get-workspace
	   (& ,(symbol->string name))
	   ,(if (pair? throw) `',throw throw)
	   %this))))

;*---------------------------------------------------------------------*/
;*    js-not ...                                                       */
;*---------------------------------------------------------------------*/
(define (js-not expr)
   (match-case expr
      (((kwote not) ?val) val)
      (else `(not ,expr))))

;*---------------------------------------------------------------------*/
;*    j2s-string->jsstring ...                                         */
;*---------------------------------------------------------------------*/
(define (j2s-string->jsstring val::bstring)
   `(& ,val))

;*---------------------------------------------------------------------*/
;*    js-pcache ...                                                    */
;*---------------------------------------------------------------------*/
(define (js-pcache cache)
   `(js-pcache-ref %pcache ,cache))

;*---------------------------------------------------------------------*/
;*    j2s-get ...                                                      */
;*---------------------------------------------------------------------*/
(define (j2s-get loc obj field tyobj prop typrop tyval conf cache
	   optim-arrayp #!optional (cspecs '(cmap pmap amap vtable)))
   
   (define (js-get obj prop %this)
      (if (config-get conf :profile-cache #f)
	  `(js-get/debug ,(box obj tyobj conf) ,prop %this ',loc)
	  `(js-get ,(box obj tyobj conf) ,prop %this)))
   
   (define (maybe-string? prop typrop)
      (and (not (number? prop))
	   (not (type-number? typrop))
	   (not (eq? typrop 'array))))
   
   (let ((propstr (match-case prop
		     ((& ?str) str)
		     (else #f))))
      (cond
	 ((> (bigloo-debug) 0)
	  (if (string? prop)
	      `(js-get/debug ,obj (& ,prop) %this ',loc)
	      `(js-get/debug ,obj ,(box prop typrop conf) %this ',loc)))
	 ((eq? tyobj 'array)
	  (case typrop
	     ((uint32)
	      `(js-array-index-ref ,obj ,prop %this))
	     ((int32)
	      `(js-array-fixnum-ref ,obj (int32->fixnum ,prop) %this))
	     (else
	      (if (and (string? prop) (string=? prop "length"))
		  (if (eq? tyval 'uint32)
		      `(js-array-length ,obj)
		      (box `(js-array-length ,obj) 'uint32 conf))
		  `(js-array-ref ,obj ,prop %this)))))
	 ((eq? tyobj 'string)
	  (cond
	     ((type-uint32? typrop)
	      `(js-jsstring-ref ,obj ,prop))
	     ((type-int32? typrop)
	      (if (or (symbol? prop) (number? prop))
		  `(if (>=fx ,prop 0)
		       (js-jsstring-ref ,obj (fixnum->uint32 ,prop))
		       (js-undefined))
		  (let ((tmp (gensym '%tmp)))
		     `(let ((,tmp ,prop))
			 (if (>=fx ,tmp 0)
			     (js-jsstring-ref ,obj (fixnum->uint32 ,tmp))
			     (js-undefined))))))
	     ((and (string? prop) (string=? prop "length") (eq? tyval 'uint32))
	      `(js-jsstring-length ,obj))
	     (else
	      `(js-get-string ,obj ,prop %this))))
	 ((and cache cspecs)
	  (cond
	     ((string? propstr)
	      (if (string=? propstr "length")
		  (if (eq? tyval 'uint32)
		      `(js-get-lengthu32 ,obj %this ,(js-pcache cache))
		      `(js-get-length ,obj %this ,(js-pcache cache)))
		  (case tyobj
		     ((object this)
		      `(js-object-get-name/cache ,obj ,prop #f %this
			  ,(js-pcache cache) ,(loc->point loc) ',cspecs))
		     ((global)
		      `(js-global-object-get-name/cache ,obj ,prop #f %this
			  ,(js-pcache cache) ,(loc->point loc) ',cspecs))
		     (else
		      `(js-get-name/cache ,obj
			  (& ,prop) #f %this
			  ,(js-pcache cache) ,(loc->point loc) ',cspecs)))))
	     ((memq typrop '(int32 uint32))
	      (js-get obj (box prop typrop conf) '%this))
	     ((and (maybe-string? prop typrop) (symbol? obj))
	      `(js-get/cache ,obj ,prop %this
		  ,(js-pcache cache) ,(loc->point loc) ',cspecs))
	     (else
	      (js-get obj prop '%this))))
	 ((string? propstr)
	  (if (string=? propstr "length")
	      (if (eq? tyval 'uint32)
		  `(js-get-lengthu32 ,obj %this #f)
		  `(js-get-length ,obj %this #f))
	      `(js-get ,(box obj tyobj conf) ,prop %this)))
	 ((and field optim-arrayp (mightbe-number? field))
	  (let ((o (gensym '%obj))
		(p (gensym '%prop)))
	     `(let ((,o ,obj)
		    (,p ,prop))
		 (if (js-array? ,o)
		     (js-array-ref ,o ,p %this)
		     ,(js-get o p '%this)))))
	 ((memq typrop '(int32 uint32))
	  (js-get obj (box prop typrop conf) '%this))
	 (else
	  (js-get obj prop '%this)))))

;*---------------------------------------------------------------------*/
;*    j2s-put! ...                                                     */
;*---------------------------------------------------------------------*/
(define (j2s-put! loc obj field tyobj prop typrop val tyval mode conf cache
	   optim-arrayp #!optional (cspecs '(cmap pmap amap vtable)))

   (define (js-put! o p v mode %this)
      (if (config-get conf :profile-cache #f)
	  `(js-put/debug! ,o ,p ,v ,mode %this ',loc)
	  `(js-put! ,o ,p ,v ,mode %this)))
   
   (define (maybe-array-set! prop val)
      (let ((o (gensym '%obj))
	    (p (gensym '%prop))
	    (v (gensym '%val)))
	 `(let ((,o ,obj)
		(,p ,prop)
		(,v ,val))
	     (if (js-array? ,o)
		 (js-array-set! ,o ,p ,v ,mode %this)
		 ,(js-put! o p v mode '%this)))))

   (define (maybe-string? prop typrop)
      (and (not (number? prop))
	   (not (type-number? typrop))
	   (not (eq? typrop 'array))))

   (let ((propstr (match-case prop
		     ((& ?str) str)
		     (else #f))))
      (cond
	 ((> (bigloo-debug) 0)
	  (if (string? prop)
	      `(js-put/debug! ,obj (& ,prop)
		  ,(box val tyval conf) ,mode %this ',loc)
	      `(js-put/debug! ,obj ,(box prop typrop conf)
		  ,(box val tyval conf) ,mode %this ',loc)))
	 ((eq? tyobj 'array)
	  (case typrop
	     ((uint32)
	      `(js-array-index-set! ,obj ,prop
		  ,(box val tyval conf) ,(strict-mode? mode) %this))
	     ((int32)
	      `(js-array-fixnum-set! ,obj (int32->fixnum ,prop)
		  ,(box val tyval conf) ,(strict-mode? mode) %this))
	     ((string)
	      `(js-array-string-set! ,obj ,prop
		  ,(box val tyval conf) ,(strict-mode? mode) %this))
	     (else
	      `(js-array-set! ,obj ,prop ,(box val tyval conf)
		  ,(strict-mode? mode) %this))))
	 ((and cache cspecs)
	  (cond
	     ((string? propstr)
	      (if (string=? propstr "length")
		  `(js-put-length! ,obj ,val
		      ,mode ,(js-pcache cache) %this)
		  (begin
		     (case tyobj
			((object global this)
			 `(js-object-put-name/cache! ,obj ,prop
			     ,(box val tyval conf)
			     ,mode %this
			     ,(js-pcache cache) ,(loc->point loc) ',cspecs))
			(else
			 `(js-put-name/cache! ,obj ,prop
			     ,(box val tyval conf)
			     ,mode %this
			     ,(js-pcache cache) ,(loc->point loc) ',cspecs))))))
	     ((memq typrop '(int32 uint32))
	      `(maybe-array-set! ,obj ,(box prop typrop conf)
		  ,(box val tyval conf) ,mode %this))
	     ((or (number? prop) (null? cspecs))
	      (maybe-array-set! prop (box val tyval conf)))
	     ((and (maybe-string? prop typrop) (symbol? obj))
	     `(js-put/cache! ,obj ,prop
		  ,(box val tyval conf) ,mode %this ,(js-pcache cache)))
	     (else
	      `(js-put! ,obj ,prop ,(box val tyval conf) ,mode %this))))
	 ((and field optim-arrayp (mightbe-number? field))
	  (maybe-array-set! (box prop typrop conf) (box val tyval conf)))
	 (else
	  (cond
	     ((string? propstr)
	      (js-put! obj prop (box val tyval conf) mode '%this))
	     ((and optim-arrayp (memq typrop '(int32 uint32)))
	      (maybe-array-set! (box prop typrop conf) (box val tyval conf)))
	     (else
	      (js-put! obj (box prop typrop conf)
		  (box val tyval conf) mode '%this)))))))

;*---------------------------------------------------------------------*/
;*    ranges                                                           */
;*---------------------------------------------------------------------*/
(define-macro (max-uint32)
   '(-u32 (bit-lshu32 #u32:1 31) #u32:1))
(define-macro (max-int32)
   '(int32->fixnum
     (uint32->int32 (-u32 (bit-lshu32 #u32:1 31) #u32:1))))
(define-macro (min-int32)
   '(int32->fixnum
     (-s32 (negs32 (uint32->int32 (-u32 (bit-lshu32 #u32:1 31) #u32:1))) #s32:1)))

;*---------------------------------------------------------------------*/
;*    inrange-positive? ...                                            */
;*---------------------------------------------------------------------*/
(define (inrange-positive? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val) #t)
	     ((int32? val) (>=s32 val #s32:0))
	     ((fixnum? val) (>fx val 0))
	     (else #f)))
       (with-access::J2SExpr expr (range type)
	  (if (interval? range)
	      (and (>=llong (interval-min range) #l0)
		   (eq? (interval-type range) 'integer))
	      (eq? type 'uint32)))))

;*---------------------------------------------------------------------*/
;*    inrange-positive-number? ...                                     */
;*---------------------------------------------------------------------*/
(define (inrange-positive-number? expr)
   (when (memq (j2s-type expr) '(integer number real int32 uint32))
      (with-access::J2SExpr expr (range)
	 (when (interval? range)
	    (>=llong (interval-min range) #l0)))))

;*---------------------------------------------------------------------*/
;*    inrange-one? ...                                                 */
;*---------------------------------------------------------------------*/
(define (inrange-one? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val) (<=u32 val #u32:1))
	     ((int32? val) (and (>=s32 val #s32:-1) (>=s32 val #s32:1)))
	     ((fixnum? val) (and (>=fx val -1) (<=fx val 1)))
	     (else #f)))
       (with-access::J2SExpr expr (range)
	  (when (interval? range)
	     (and (>=llong (interval-min range) #l-1)
		  (<=llong (interval-max range) #l1)
		  (eq? (interval-type range) 'integer))))))

;*---------------------------------------------------------------------*/
;*    inrange-32? ...                                                  */
;*---------------------------------------------------------------------*/
(define (inrange-32? expr)
   (with-access::J2SExpr expr (range)
      (and (interval? range)
	   (>= (interval-min range) #l0)
	   (< (interval-max range) #l32)
	   (eq? (interval-type range) 'integer))))

;*---------------------------------------------------------------------*/
;*    inrange-int30? ...                                               */
;*---------------------------------------------------------------------*/
(define (inrange-int30? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val)
	      (<u32 val (bit-lshu32 #u32:1 29)))
	     ((int32? val)
	      (and (>=s32 val (negs32 (bit-lshs32 #u32:1 29)))
		   (<s32 val (bit-lshs32 #s32:1 29))))
	     ((fixnum? val)
	      (and (>=fx val (negfx (bit-lsh 1 29)))
		   (<fx val (bit-lsh 1 29))))
	     (else #f)))
       (with-access::J2SExpr expr (range)
	  (when (interval? range)
	     (and (>=llong (interval-min range) (- (bit-lshllong #l1 29)))
		  (<llong (interval-max range) (bit-lshllong #l1 29))
		  (eq? (interval-type range) 'integer))))))

;*---------------------------------------------------------------------*/
;*    inrange-uint30? ...                                              */
;*---------------------------------------------------------------------*/
(define (inrange-uint30? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val)
	      (<u32 val (bit-lshu32 #u32:1 29)))
	     ((int32? val)
	      (and (>=s32 val 0) (<s32 val (bit-lshs32 #s32:1 29))))
	     ((fixnum? val)
	      (and (>=fx val 0) (<fx val (bit-lsh 1 29))))
	     (else #f)))
       (with-access::J2SExpr expr (range)
	  (when (interval? range)
	     (and (>=llong (interval-min range) 0)
		  (<llong (interval-max range) (bit-lshllong #l1 30))
		  (eq? (interval-type range) 'integer))))))

;*---------------------------------------------------------------------*/
;*    inrange-int32? ...                                               */
;*---------------------------------------------------------------------*/
(define (inrange-int32? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val)
	      (<u32 val (-u32 (bit-lshu32 #u32:1 31) #u32:1)))
	     ((int32? val)
	      #t)
	     ((fixnum? val)
	      (and (>=fx val (min-int32)) (<=fx val (max-int32))))
	     (else #f)))
       (with-access::J2SExpr expr (range type)
	  (if (interval? range)
	      (and (>=llong (interval-min range) (- (bit-lshllong #l1 31)))
		   (<llong (interval-max range) (bit-lshllong #l1 31))
		   (eq? (interval-type range) 'integer))
	      (eq? type 'int32)))))

;*---------------------------------------------------------------------*/
;*    inrange-uint32? ...                                              */
;*---------------------------------------------------------------------*/
(define (inrange-uint32? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val) #t)
	     ((int32? val) (>=s32 val #s32:0))
	     ((fixnum? val) (>=fx val 0))
	     (else #f)))
       (with-access::J2SExpr expr (range type)
	  (if (interval? range)
	      (and (>=llong (interval-min range) #l0)
		   (<llong (interval-max range) (bit-lshllong #l1 32))
		   (eq? (interval-type range) 'integer))
	      (eq? type 'uint32)))))

;*---------------------------------------------------------------------*/
;*    inrange-uint32-number? ...                                       */
;*---------------------------------------------------------------------*/
(define (inrange-uint32-number? expr)
   (with-access::J2SExpr expr (range)
      (when (inrange-positive-number? expr)
	 (<llong (interval-max range) (bit-lshllong #l1 32)))))

;*---------------------------------------------------------------------*/
;*    inrange-int53? ...                                               */
;*---------------------------------------------------------------------*/
(define (inrange-int53? expr)
   (if (isa? expr J2SNumber)
       (with-access::J2SNumber expr (val)
	  (cond
	     ((uint32? val) #t)
	     ((int32? val) #t)
	     ((fixnum? val)
	      (or (and (>=fx val (negfx (bit-lsh 1 29)))
		       (<fx val (bit-lsh 1 29)))
		  (let ((lval (fixnum->llong val)))
		     (and (>=llong lval (negllong (bit-lshllong #l1 53)))
			  (<llong lval (bit-lshllong #l1 53))))))
	     (else #f)))
       (with-access::J2SExpr expr (range type)
	  (if (interval? range)
	      (and (>=llong (interval-min range) (- (bit-lshllong #l1 53)))
		   (<llong (interval-max range) (bit-lshllong #l1 53))
		   (eq? (interval-type range) 'integer))
	      (memq type '(int32 uint32 integer bint))))))

;*---------------------------------------------------------------------*/
;*    box ...                                                          */
;*---------------------------------------------------------------------*/
(define (box val type conf #!optional proc::obj)
   (if (m64? conf)
       (box64 val type conf proc)
       (box32 val type conf proc)))

;*---------------------------------------------------------------------*/
;*    box32 ...                                                        */
;*---------------------------------------------------------------------*/
(define (box32 val type::symbol conf #!optional proc::obj)

   (case type
      ((int32)
       (if (int32? val)
	   (if (and (>=llong (int32->llong val) (conf-min-int conf))
		    (<=llong (int32->llong val) (conf-max-int conf)))
	       (cond-expand
		  (bint30
		   (if (and (>=llong (int32->llong val)
			       (negllong (bit-lshllong #l1 29)))
			    (<llong (int32->llong val)
			       (bit-lshllong #l1 29)))
		       (int32->fixnum val)
		       `(int32->fixnum ,val)))
		  (else
		   (int32->fixnum val))))
	   `(overflowfx (int32->fixnum ,val))))
      ((uint32)
       (if (uint32? val)
	   (if (<=llong (uint32->llong val) (conf-max-int conf))
	       (uint32->fixnum val)
	       (uint32->flonum val))
	   `(if (<u32 ,val ,(llong->uint32 (conf-max-int conf)))
		(uint32->fixnum ,val)
		(uint32->flonum ,val))))
      ((integer)
       (if (fixnum? val)
	   (if (and (>=llong (fixnum->llong val) (conf-min-int conf))
		    (<=llong (fixnum->llong val) (conf-max-int conf)))
	       val
	       (fixnum->flonum val))
	   `(overflowfx ,val)))
      ((real number)
       val)
      (else
       (if (not proc) val (proc val)))))

;*---------------------------------------------------------------------*/
;*    box64 ...                                                        */
;*---------------------------------------------------------------------*/
(define (box64 val type::symbol conf #!optional proc::obj)
   (case type
      ((int32) (if (int32? val) (int32->fixnum val) `(int32->fixnum ,val)))
      ((uint32) (if (uint32? val) (uint32->fixnum val) `(uint32->fixnum ,val)))
      ((int53 integer real number) val)
      (else (if (not proc) val (proc val)))))

;*---------------------------------------------------------------------*/
;*    expr-asuint32 ...                                                */
;*    -------------------------------------------------------------    */
;*    If an expression can be interpreted as an uint32 without         */
;*    cast, return that subexpression.                                 */
;*---------------------------------------------------------------------*/
(define (expr-asuint32 expr::J2SExpr)
   (cond
      ((eq? (j2s-vtype expr) 'uint32)
       expr)
      ((eq? (j2s-type expr) 'uint32)
       expr)
      ((isa? expr J2SCast)
       (with-access::J2SCast expr (expr)
	  (expr-asuint32 expr)))
      ((inrange-uint32? expr)
       expr)
      (else
       #f)))

;*---------------------------------------------------------------------*/
;*    uncast ...                                                       */
;*---------------------------------------------------------------------*/
(define (uncast::J2SExpr expr::J2SExpr)
   (if (isa? expr J2SCast)
       (with-access::J2SCast expr (expr)
	  (uncast expr))
       expr))

;*---------------------------------------------------------------------*/
;*    cancall? ...                                                     */
;*---------------------------------------------------------------------*/
(define (cancall? node)
   (let ((cell (make-cell #f)))
      (cancall node cell)
      (cell-ref cell)))

;*---------------------------------------------------------------------*/
;*    cancall ::J2SNode ...                                            */
;*---------------------------------------------------------------------*/
(define-walk-method (cancall this::J2SNode cell)
   (or (cell-ref cell) (call-default-walker)))

;*---------------------------------------------------------------------*/
;*    cancall ::J2SCall ...                                            */
;*---------------------------------------------------------------------*/
(define-walk-method (cancall this::J2SCall cell)
   (cell-set! cell #t))

;*---------------------------------------------------------------------*/
;*    cancall ::J2SNew ...                                             */
;*---------------------------------------------------------------------*/
(define-walk-method (cancall this::J2SNew cell)
   (cell-set! cell #t))

;*---------------------------------------------------------------------*/
;*    cancall ::J2SAssig ...                                           */
;*---------------------------------------------------------------------*/
(define-walk-method (cancall this::J2SAssig cell)
   (with-access::J2SAssig this (lhs rhs)
      (if (isa? lhs J2SAccess)
	  (with-access::J2SAccess lhs (obj field)
	     (unless (isa? obj J2SThis)
		(cancall field cell)
		(cancall rhs cell)))
	  (begin
	     (cancall lhs cell)
	     (cancall rhs cell)))))

;*---------------------------------------------------------------------*/
;*    optimized-ctor ...                                               */
;*---------------------------------------------------------------------*/
(define (optimized-ctor this::J2SNode)
   (let loop ((this this))
      (cond
	 ((isa? this J2SRef)
	  (with-access::J2SRef this (decl)
	     (loop decl)))
	 ((isa? this J2SParen)
	  (with-access::J2SParen this (expr)
	     (loop expr)))
	 ((isa? this J2SDeclFun)
	  (with-access::J2SDeclFun this (scope usage val)
	     (unless (memq scope '(none letblock))
		(when (and (usage? '(new) usage)
			   (not (usage? '(call) usage))
			   (not (usage? '(assig) usage)))
		   (with-access::J2SFun val (rtype vararg)
		      (when (and (eq? rtype 'undefined) (not vararg))
			 this))))))
	 (else
	  #f))))
