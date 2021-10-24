;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/ast.sch                   */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Mon Jan 11 13:06:45 2016                          */
;*    Last change :  Sun Oct 24 08:31:14 2021 (serrano)                */
;*    Copyright   :  2016-21 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Minimal set of macros for creating new AST.                      */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    interval ...                                                     */
;*---------------------------------------------------------------------*/
(define-struct interval min max type)

;*---------------------------------------------------------------------*/
;*    Small macro-based API for helping creating J2SNode               */
;*---------------------------------------------------------------------*/
(define-macro (J2SUndefined)
   `(instantiate::J2SUndefined
       (type 'undefined)
       (loc loc)))

(define-macro (J2SNull)
   `(instantiate::J2SNull
       (type 'null)
       (loc loc)))

(define-macro (J2SBool val)
   `(instantiate::J2SBool
       (loc loc)
       (type 'bool)
       (val ,val)))

(define-macro (J2SNumber val)
   `(instantiate::J2SNumber
       (loc loc)
       (val ,val)))

(define-macro (J2SNumber/type typ val)
   `(instantiate::J2SNumber
       (loc loc)
       (type ,typ)
       (val ,val)))

(define-macro (J2SString val)
   `(instantiate::J2SString
       (loc loc)
       (val ,val)))

(define-macro (J2SNativeString val)
   `(instantiate::J2SNativeString
       (loc loc)
       (val ,val)))

(define-macro (J2SArray . exprs)
   `(instantiate::J2SArray
       (loc loc)
       (len ,(length exprs))
       (type 'array)
       (exprs ,(if (pair? exprs) `(list ,@exprs) ''()))))

(define-macro (J2SArray* size exprs)
   `(instantiate::J2SArray
       (loc loc)
       (len ,size)
       (type 'array)
       (exprs ,exprs)))

(define-macro (J2SNop)
   `(instantiate::J2SNop
       (loc loc)))

(define-macro (J2SNew clazz . args)
   `(instantiate::J2SNew
       (loc loc)
       (clazz ,clazz)
       (args ,(if (pair? args) `(list ,@args) ''()))))

(define-macro (J2SNew* clazz args)
   `(instantiate::J2SNew
       (loc loc)
       (clazz ,clazz)
       (args ,args)))

(define-macro (J2SPragma expr)
   `(instantiate::J2SPragma
       (loc loc)
       (expr ,expr)))

(define-macro (J2SPragma/type type expr)
   `(instantiate::J2SPragma
       (loc loc)
       (type ,type)
       (expr ,expr)))

(define-macro (J2SPragma/bindings type vars vals expr)
   `(instantiate::J2SPragma
       (loc loc)
       (type ,type)
       (vars ,vars)
       (vals ,vals)
       (expr ,expr)))

(define-macro (J2SParen expr)
   `(instantiate::J2SParen
       (loc loc)
       (expr ,expr)))

(define-macro (J2SUnary op expr)
   `(instantiate::J2SUnary
       (type 'unknown)
       (loc loc)
       (op ,op)
       (expr ,expr)))

(define-macro (J2SUnary/type op typ expr)
   `(instantiate::J2SUnary
       (type ,typ)
       (loc loc)
       (op ,op)
       (expr ,expr)))

(define-macro (J2SBinary op lhs rhs)
   (let ((typ (match-case op
		 (((kwote quote) ?op)
		  (if (memq op '(eq? === == != !== < <= > >=))
		      'bool
		      'unknown))
		 (else
		  (error "J2SBInary" "op must be knonw, use J2SBinary/type" op)))))
      `(J2SBinary/type ,op ',typ ,lhs ,rhs)))

(define-macro (J2SBinary/type op typ lhs rhs)
   `(instantiate::J2SBinary
       (type ,typ)
       (loc loc)
       (op ,op)
       (lhs ,lhs)
       (rhs ,rhs)))

(define-macro (J2SPostfix op lhs rhs)
   `(instantiate::J2SPostfix
       (loc loc)
       (op ,op)
       (lhs ,lhs)
       (rhs ,rhs)))

(define-macro (J2SCall fun . args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs (list (J2SUndefined)))
       (args ,(if (pair? args) `(list ,@args) ''()))))

(define-macro (J2SHopCall fun . args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs '())
       (args ,(if (pair? args) `(list ,@args) ''()))))

(define-macro (J2SHopCall* fun args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs '())
       (args ,args)))

(define-macro (J2SHopCall/type type fun . args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (type ,type)
       (thisargs '())
       (args ,(if (pair? args) `(list ,@args) ''()))))

(define-macro (J2SCall* fun args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs (list (J2SUndefined)))
       (args ,args)))

(define-macro (J2SMethodCall fun thisargs . args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs ,thisargs)
       (args ,(if (pair? args) `(list ,@args) ''()))))

(define-macro (J2SMethodCall* fun thisargs args)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs ,thisargs)
       (args ,args)))

(define-macro (J2SMethodCall/cache* fun thisargs args cspecs cache)
   `(instantiate::J2SCall
       (loc loc)
       (fun ,fun)
       (thisargs ,thisargs)
       (args ,args)
       (cspecs ,cspecs)
       (cache ,cache)))

(define-macro (J2SAccess obj field)
   `(instantiate::J2SAccess
       (loc loc)
       (obj ,obj)
       (field ,field)))

(define-macro (J2SAccess/cache obj field cache cspecs)
   `(instantiate::J2SAccess
       (loc loc)
       (obj ,obj)
       (field ,field)
       (cache ,cache)
       (cspecs ,cspecs)))

(define-macro (J2SThis this)
   `(instantiate::J2SThis
       (decl ,this)
       (loc loc)))

(define-macro (J2SHopRef id . module)
   `(instantiate::J2SHopRef
       (loc loc)
       (id ,id)
       (type 'any)
       (module ,(when (pair? module) (car module)))))

(define-macro (J2SHopRef/type id type . module)
   `(instantiate::J2SHopRef
       (loc loc)
       (id ,id)
       (type ,type)
       (module ,(when (pair? module) (car module)))))

(define-macro (J2SHopRef/rtype id rtype . module)
   `(instantiate::J2SHopRef
       (loc loc)
       (id ,id)
       (type 'function)
       (rtype ,rtype)
       (module ,(when (pair? module) (car module)))))

(define-macro (J2SRef decl . opts)
   `(instantiate::J2SRef
       (loc loc)
       (type ,(let ((c (memq :type opts))) (if (pair? c) (cadr c) ''unknown)))
       (decl ,decl)))

(define-macro (J2SGlobalRef id . opts)
   `(instantiate::J2SGlobalRef
       (loc loc)
       (id ,id)
       (type ,(let ((c (memq :type opts))) (if (pair? c) (cadr c) ''unknown)))
       (decl (J2SDecl '%scope '(ref set) id))))

(define-macro (J2SUnresolvedRef id)
   `(instantiate::J2SUnresolvedRef
       (loc loc)
       (id ,id)))

(define-macro (J2SSuper decl context)
   `(instantiate::J2SSuper
       (loc loc)
       (decl ,decl)
       (context ,context)))

(define-macro (J2SFun name params body . opts)
   `(instantiate::J2SFun
       (loc loc)
       (mode 'hopscript)
       (name ,name)
       (params ,params)
       (body ,body)))

(define-macro (J2SFun* name params body . opts)
   `(instantiate::J2SFun
       (loc loc)
       (mode 'hopscript)
       (generator #t)
       (name ,name)
       (params ,params)
       (body ,body)))

(define-macro (J2SArrow name params body . opts)
   `(instantiate::J2SArrow
       (loc loc)
       (idthis '%_)
       (mode 'hopscript)
       (name ,name)
       (params ,params)
       (body ,body)))

(define-macro (J2SArrowKont name params body . opts)
   `(instantiate::J2SArrow
       (loc loc)
       (idthis '%gen)
       (mode 'hopscript)
       (name ,name)
       (params ,params)
       (body ,body)))

(define-macro (J2SArrow/rtype rtype name params body . opts)
   `(instantiate::J2SArrow
       (loc loc)
       (idthis '%_)
       (mode 'hopscript)
       (name ,name)
       (params ,params)
       (rtype ,rtype)
       (body ,body)))

(define-macro (J2SBlock . nodes)
   `(instantiate::J2SBlock
       (loc loc)
       (endloc endloc)
       (nodes ,(if (pair? nodes) `(list ,@nodes) ''()))))

(define-macro (J2SBlock/w-endloc . nodes)
   `(instantiate::J2SBlock
       (loc loc)
       (endloc loc)
       (nodes ,(if (pair? nodes) `(list ,@nodes) ''()))))

(define-macro (J2SBlock* nodes)
   `(instantiate::J2SBlock
       (loc loc)
       (endloc endloc)
       (nodes ,nodes)))

(define-macro (J2SBlock*/w-endloc nodes)
   `(instantiate::J2SBlock
       (loc loc)
       (endloc loc)
       (nodes ,nodes)))

(define-macro (J2SSeq . nodes)
   `(instantiate::J2SSeq
       (loc loc)
       (nodes ,(if (pair? nodes) `(list ,@nodes) ''()))))

(define-macro (J2SSeq* nodes)
   `(instantiate::J2SSeq
       (loc loc)
       (nodes ,nodes)))

(define-macro (J2SSequence . exprs)
   `(instantiate::J2SSequence
       (loc loc)
       (exprs ,(if (pair? exprs) `(list ,@exprs) ''()))))

(define-macro (J2SSequence/type type . exprs)
   `(instantiate::J2SSequence
       (loc loc)
       (type ,type)
       (exprs ,(if (pair? exprs) `(list ,@exprs) ''()))))

(define-macro (J2SSequence* exprs)
   `(instantiate::J2SSequence
       (loc loc)
       (exprs ,exprs)))

(define-macro (J2SSequence/type* type exprs)
   `(instantiate::J2SSequence
       (loc loc)
       (type ,type)
       (exprs ,exprs)))

(define-macro (J2SLetBlock decls . nodes)
   `(instantiate::J2SLetBlock
       (loc loc)
       (endloc loc)
       (decls ,decls)
       (nodes ,(if (pair? nodes) `(list ,@nodes) ''()))))

(define-macro (J2SLetBlock* decls nodes)
   `(instantiate::J2SLetBlock
       (loc loc)
       (endloc loc)
       (decls ,decls)
       (nodes ,nodes)))

(define-macro (J2SLetRecBlock rec decls . nodes)
   `(instantiate::J2SLetBlock
       (loc loc)
       (rec ,rec)
       (endloc loc)
       (decls ,decls)
       (nodes ,(if (pair? nodes) `(list ,@nodes) ''()))))

(define-macro (J2SLetRecBlock* rec decls nodes)
   `(instantiate::J2SLetBlock
       (loc loc)
       (rec ,rec)
       (endloc loc)
       (decls ,decls)
       (nodes ,nodes)))

(define-macro (J2STry body catch . finally)
   `(instantiate::J2STry
       (loc loc)
       (body ,body)
       (catch ,catch)
       (finally ,(if (pair? finally) (car finally) '(J2SNop)))))

(define-macro (J2SCatch param body)
   `(instantiate::J2SCatch
       (loc loc)
       (param ,param)
       (body ,body)))

(define-macro (J2SKont param exn body)
   `(instantiate::J2SKont
       (loc loc)
       (param ,param)
       (exn ,exn)
       (body ,body)))

(define-macro (J2SYield expr gen)
   `(instantiate::J2SYield
       (loc loc)
       (expr ,expr)
       (generator ,gen)))

(define-macro (J2SReturnYield expr kont gen)
   `(instantiate::J2SReturnYield
       (loc loc)
       (expr ,expr)
       (kont ,kont)
       (generator ,gen)))

(define-macro (J2SStmtExpr expr)
   `(instantiate::J2SStmtExpr
       (loc loc)
       (expr ,expr)))

(define-macro (J2SDecl binder _usage id)
   `(instantiate::J2SDecl
       (loc loc)
       (binder ,binder)
       (usage (usage ,_usage))
       (id ,id)))

(define-macro (J2SDeclGlobal binder _usage id)
   `(instantiate::J2SDecl
       (loc loc)
       (binder ,binder)
       (scope 'global)
       (usage (usage ,_usage))
       (id ,id)))

(define-macro (J2SParam _usage id . opts)
   `(instantiate::J2SDecl
       (loc loc)
       (binder 'param)
       (usage (usage ,_usage))
       (itype ,(let ((c (memq :type opts)))
		  (if (pair? c)
		      (cadr c)
		      (let ((c (memq :vtype opts)))
			 (if (pair? c) (cadr c) ''unknown)))))
       (vtype ,(let ((c (memq :vtype opts)))
		  (if (pair? c) (cadr c) ''unknown)))
       (id ,id)))

(define-macro (J2SDeclInit _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (binder 'var)
       (usage (usage ,_usage))
       (val ,val)
       (id ,id)))

(define-macro (J2SLetOpt _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (writable (usage-has? (usage ,_usage) '(assig)))
       (usecnt 1)
       (binder 'let-opt)
       (usage (usage ,_usage))
       (val ,val)
       (id ,id)))

(define-macro (J2SLetOptRo _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (writable #f)
       (usecnt 1)
       (binder 'let-opt)
       (usage (usage-rem (usage ,_usage) 'assig))
       (val ,val)
       (id ,id)))

(define-macro (J2SLetOptRoGlobal _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (writable #f)
       (scope 'global)
       (usecnt 1)
       (binder 'let-opt)
       (usage (usage-rem (usage ,_usage) 'assig))
       (val ,val)
       (id ,id)))

(define-macro (J2SLetOpt/vtype typ usage id val)
   `(J2SLetOptVtype ,typ ,usage ,id ,val))

(define-macro (J2SLetOptVtype typ _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (writable (usage-has? (usage ,_usage) '(assig)))
       (vtype ,typ)
       (usecnt 1)
       (binder 'let-opt)
       (usage (usage ,_usage))
       (val ,val)
       (id ,id)))

(define-macro (J2SLetOptVUtype typ _usage id val)
   `(instantiate::J2SDeclInit
       (loc loc)
       (writable (usage-has? (usage ,_usage) '(assig)))
       (vtype ,typ)
       (utype ,typ)
       (usecnt 1)
       (binder 'let-opt)
       (usage (usage ,_usage))
       (val ,val)
       (id ,id)))

(define-macro (J2SDConsumer decl path expr)
   `(instantiate::J2SDConsumer
       (loc loc)
       (decl ,decl)
       (expr ,expr)
       (path ,path)))

(define-macro (J2SDConsumerIterator expr)
   `(instantiate::J2SDConsumerIterator
       (loc loc)
       (expr ,expr)))

(define-macro (%J2STail expr . from)
   `(instantiate::%J2STail
       (loc loc)
       (expr ,expr)
       (from ,(if (pair? from) (car from) #f))))

(define-macro (J2SIf test then else)
   `(instantiate::J2SIf
       (loc loc)
       (test ,test)
       (then ,then)
       (else ,else)))

(define-macro (J2SPrecache accesses then else)
   `(instantiate::J2SPrecache
       (loc loc)
       (accesses ,accesses)
       (test (J2SBool #t))
       (then ,then)
       (else ,else)))

(define-macro (J2SIfIsRecord test then else)
   `(instantiate::J2SIfIsRecord
       (loc loc)
       (test ,test)
       (then ,then)
       (else ,else)))
   
(define-macro (J2SCond test then else)
   `(instantiate::J2SCond
       (loc loc)
       (test ,test)
       (then ,then)
       (else ,else)))

(define-macro (J2SCond/type type test then else)
   `(instantiate::J2SCond
       (loc loc)
       (type ,type)
       (test ,test)
       (then ,then)
       (else ,else)))

(define-macro (J2SReturn tail expr . from)
   `(instantiate::J2SReturn
       (loc loc)
       (tail ,tail)
       (expr ,expr)
       (from ,(if (pair? from) (car from) #f))))

(define-macro (J2SBindExit lbl stmt)
   `(instantiate::J2SBindExit
       (loc loc)
       (lbl ,lbl)
       (stmt ,stmt)))

(define-macro (J2SBindExit/type typ lbl stmt)
   `(instantiate::J2SBindExit
       (loc loc)
       (lbl ,lbl)
       (type ,typ)
       (stmt ,stmt)))

(define-macro (J2SBindExit/utype typ lbl stmt)
   `(instantiate::J2SBindExit
       (loc loc)
       (lbl ,lbl)
       (utype ,typ)
       (stmt ,stmt)))

(define-macro (J2SAssig lhs rhs)
   `(instantiate::J2SAssig
       (loc loc)
       (lhs ,lhs)
       (rhs ,rhs)))

(define-macro (J2SAssig/type type lhs rhs)
   `(instantiate::J2SAssig
       (loc loc)
       (type ,type)
       (lhs ,lhs)
       (rhs ,rhs)))

(define-macro (J2SInit lhs rhs)
   `(instantiate::J2SInit
       (loc loc)
       (lhs ,lhs)
       (rhs ,rhs)))

(define-macro (J2SThrow expr)
   `(instantiate::J2SThrow
       (loc loc)
       (expr ,expr)))

(define-macro (J2SSwitch key cases)
   `(instantiate::J2SSwitch
       (loc loc)
       (key ,key)
       (cases ,cases)))

(define-macro (J2SDefault body)
   `(instantiate::J2SDefault
       (loc loc)
       (expr (J2SUndefined))
       (body ,body)))

(define-macro (J2SFor init test incr body)
   `(instantiate::J2SFor
       (loc loc)
       (init ,init)
       (test ,test)
       (incr ,incr)
       (body ,body)))

(define-macro (J2SWhile test body)
   `(instantiate::J2SWhile
       (loc loc)
       (test ,test)
       (body ,body)))

(define-macro (J2SCast totype expr)
   `(instantiate::J2SCast
       (loc loc)
       (expr ,expr)
       (type ,totype)))

(define-macro (J2SCast/static static totype expr)
   `(instantiate::J2SCast
       (loc loc)
       (expr ,expr)
       (static ,static)
       (type ,totype)))

(define-macro (J2SCheck totype expr)
   `(instantiate::J2SCheck
       (loc loc)
       (expr ,expr)
       (type ,totype)))

(define-macro (J2SMeta meta debug optim stmt)
   `(instantiate::J2SMeta
       (loc loc)
       (meta ,meta)
       (optim ,optim)
       (debug ,debug)
       (stmt ,stmt)))

(define-macro (J2SCacheCheck prop cache owner obj . fields)
   `(instantiate::J2SCacheCheck
       (loc loc)
       (prop ,prop)
       (cache ,cache)
       (owner ,owner)
       (obj ,obj)
       (type 'bool)
       (fields ,(if (pair? fields) `(list ,@fields) ''()))))

(define-macro (J2SCacheUpdate prop cache obj)
   `(instantiate::J2SCacheUpdate
       (loc loc)
       (prop ,prop)
       (cache ,cache)
       (obj ,obj)))

(define-macro (J2SKontRef gen index id)
   `(instantiate::J2SKontRef
       (loc loc)
       (gen ,gen)
       (index ,index)
       (id ,id)))
