;*=====================================================================*/
;*    serrano/prgm/project/hop/3.2.x/hopscript/lib.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Tue Oct  8 08:16:17 2013                          */
;*    Last change :  Tue Jan 15 09:38:49 2019 (serrano)                */
;*    Copyright   :  2013-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    The Hop client-side compatibility kit (share/hop-lib.js)         */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_lib

   (library hop)

   (include "types.sch" "property.sch")
   
   (import __hopscript_types
	   __hopscript_arithmetic
	   __hopscript_property
	   __hopscript_object
	   __hopscript_function
	   __hopscript_public
	   __hopscript_worker
	   __hopscript_stringliteral
	   __hopscript_array
	   __hopscript_date
	   __hopscript_boolean
	   __hopscript_number
	   __hopscript_regexp
	   __hopscript_arraybuffer
	   __hopscript_arraybufferview)

   (export (js-constant-init ::bstring ::JsGlobalObject)
	   (generic js-obj->jsobject ::obj ::JsGlobalObject)
	   (js-literal->jsobject::JsObject ::vector ::vector ::JsGlobalObject)
	   (js-alist->jsobject::JsObject ::pair-nil ::JsGlobalObject)
	   (js-plist->jsobject::JsObject ::pair-nil ::JsGlobalObject)
	   (js-jsobject->plist ::JsObject ::JsGlobalObject)
	   (js-jsobject->keyword-plist ::JsObject ::JsGlobalObject)
	   (js-jsobject->alist ::JsObject ::JsGlobalObject)
	   (js-dsssl-args->jsargs ::pair ::JsGlobalObject)
	   (js-object->keyword-arguments*::pair-nil ::JsObject ::JsGlobalObject)
	   (js-iterable->list::pair-nil ::obj ::JsGlobalObject)
	   (generic js-jsobject->jsarray ::obj ::JsGlobalObject)
	   (inline fixnums?::bool ::obj ::obj)))

;*---------------------------------------------------------------------*/
;*    js-constant-init ...                                             */
;*---------------------------------------------------------------------*/
(define (js-constant-init str %this)
   (let ((cnsts (string->obj str)))
      (let loop ((i (-fx (vector-length cnsts) 1)))
	 (when (>=fx i 0)
	    (let ((el (vector-ref cnsts i)))
	       (cond
		  ((isa? el JsRegExp)
		   ;; patch the regexp prototype
		   (with-access::JsGlobalObject %this (js-regexp-prototype)
		      (with-access::JsRegExp el (__proto__ cmap)
			 (set! cmap js-regexp-cmap)
			 (set! __proto__ js-regexp-prototype))))
		  ((vector? el)
		   (vector-set! cnsts i
		      (case (vector-ref el 0)
			 ((0)
			  ;; a plain string
			  (let ((str (vector-ref el 1)))
			     (js-string->jsstring str)))
			 ((1 4)
			  ;; a plain regexp
			  (with-access::JsGlobalObject %this (js-regexp)
			     (let* ((cnsts (vector-ref el 1))
				    (flags (vector-ref el 2))
				    (rx (js-string->jsstring cnsts)))
				(if flags
				    (if (eq? (vector-ref el 0) 4)
					(js-new3 %this js-regexp rx
					   (js-string->jsstring flags)
					   (vector-ref el 3))
					(js-new2 %this js-regexp rx
					   (js-string->jsstring flags)))
				    (if (eq? (vector-ref el 0) 4)
					(js-new2 %this js-regexp rx
					   (vector-ref el 3))
					(js-new1 %this js-regexp rx))))))
			 ((2)
			  ;; a literal cmap
			  (let ((props (vector-ref el 1)))
			     (js-names->cmap props)))
			 ((3 5)
			  ;; an inlined regexp
			  (with-access::JsGlobalObject %this (js-regexp)
			     (let* ((cnsts (vector-ref el 1))
				    (flags (vector-ref el 2))
				    (rx (js-string->jsstring cnsts))
				    (regexp (if flags
						(if (eq? (vector-ref el 0) 5)
						    (js-new3 %this js-regexp rx
						       (js-string->jsstring flags)
						       (vector-ref el 3))
						    (js-new2 %this js-regexp rx
						       (js-string->jsstring flags)))
						(if (eq? (vector-ref el 0) 5)
						    (js-new2 %this js-regexp rx
						       (vector-ref el 3))
						    (js-new1 %this js-regexp rx)))))
				(with-access::JsRegExp regexp (rx)
				   rx))))))))
	       (loop (-fx i 1)))))
      cnsts))

;*---------------------------------------------------------------------*/
;*    js-obj->jsobject ...                                             */
;*---------------------------------------------------------------------*/
(define-generic (js-obj->jsobject obj::obj %this::JsGlobalObject)
   (cond
      ((number? obj) (js-number->jsnumber obj))
      ((boolean? obj) obj)
      ((eq? obj #unspecified) obj)
      ((null? obj) obj)
      ((string? obj) (js-string->jsstring obj))
      ((date? obj) (js-date->jsdate obj %this))
      ((vector? obj) (js-vector->jsobject obj %this))
      ((struct? obj) (js-struct->jsobject obj %this))
      ((regexp? obj) (js-regexp->jsregexp obj %this))
      ((keyword? obj) (js-string->jsstring (keyword->string obj)))
      ((symbol? obj) (js-string->jsstring (symbol->string obj)))
      ((pair? obj) (js-pair->jsobject obj %this))
      ((u8vector? obj) (js-u8vector->jsarraybuffer obj %this))
      ((null? obj) (js-undefined))
      ((socket? obj) (js-socket->jsobject obj %this))
      ((procedure? obj) (js-procedure->jsobject obj %this))
      (else (js-undefined))))

;*---------------------------------------------------------------------*/
;*    js-vector->jsobject ...                                          */
;*---------------------------------------------------------------------*/
(define (js-vector->jsobject vec %this)
   (let ((vec (vector-map (lambda (o) (js-obj->jsobject o %this)) vec)))
      (js-vector->jsarray vec %this)))

;*---------------------------------------------------------------------*/
;*    js-struct->jsobject ...                                          */
;*---------------------------------------------------------------------*/
(define (js-struct->jsobject stu %this)
   (case (struct-key stu)
      ((__JsBoolean__) (js-bool->jsBoolean (struct-ref stu 0) %this))
      ((__JsNumber__) (js-number->jsNumber (struct-ref stu 0) %this))
      ((__JsCustom__) ((struct-ref stu 1) (struct-ref stu 0) %this))
      (else (js-obj->jsobject (list->vector (struct->list stu)) %this))))

;*---------------------------------------------------------------------*/
;*    js-pair->jsobject ...                                            */
;*---------------------------------------------------------------------*/
(define (js-pair->jsobject l %this)
   
   (define (plist? l)
      (let loop ((l l))
	 (cond
	    ((null? l)
	     #t)
	    ((and (or (keyword? (car l)) (symbol? (car l))) (pair? (cdr l)))
	     (loop (cddr l)))
	    (else
	     #f))))

   (define (alist? l)
      (when (list? l)
	 (every (lambda (e)
		   (and (pair? e) (or (keyword? (car e)) (symbol? (car e)))))
	    l)))

   (cond
      ((plist? l)
       (js-plist->jsobject l %this))
      ((alist? l)
       (js-alist->jsobject l %this))
      ((list? l)
       (map (lambda (o) (js-obj->jsobject o %this)) l))
      (else
       (cons (js-obj->jsobject (car l) %this) (js-obj->jsobject (cdr l) %this)))))

;*---------------------------------------------------------------------*/
;*    js-literal->jsobject ...                                         */
;*    -------------------------------------------------------------    */
;*    The cmap structure is defined in property.scm.                   */
;*---------------------------------------------------------------------*/
(define (js-literal->jsobject::JsObject elements::vector names::vector %this)
   (with-access::JsGlobalObject %this (__proto__)
      (instantiateJsObject
	 (cmap (js-names->cmap names))
	 (__proto__ __proto__)
	 (elements elements))))

;*---------------------------------------------------------------------*/
;*    js-alist->jsobject ...                                           */
;*    -------------------------------------------------------------    */
;*    The cmap structure is defined in property.scm.                   */
;*---------------------------------------------------------------------*/
(define (js-alist->jsobject alist %this)
   (with-access::JsGlobalObject %this (js-object __proto__)
      (let* ((len (length alist))
	     (elements ($create-vector len))
	     (props ($create-vector len))
	     (methods (make-vector len #f)))
	 (let loop ((i 0)
		    (alist alist))
	    (if (=fx i len)
		(let ((cmap (instantiate::JsConstructMap
			       (props props)
			       (methods methods))))
		   (instantiateJsObject
		      (cmap cmap)
		      (__proto__ __proto__)
		      (elements elements)))
		(let* ((name (cond
				((keyword? (caar alist))
				 (keyword->symbol (caar alist)))
				((string? (caar alist))
				 (string->symbol (caar alist)))
				(else
				 (caar alist))))
		       (val (js-obj->jsobject (cdar alist) %this)))
		   (vector-set! props i (prop name (property-flags-default)))
		   (vector-set! elements i val)
		   (when (isa? val JsFunction) (vector-set! methods i #t))
		   (loop (+fx i 1) (cdr alist))))))))

;*---------------------------------------------------------------------*/
;*    js-plist->jsobject ...                                           */
;*---------------------------------------------------------------------*/
(define (js-plist->jsobject plist %this)
   (with-access::JsGlobalObject %this (js-object __proto__)
      (let* ((len (/fx (length plist) 2))
	     (elements ($create-vector len))
	     (props ($create-vector len))
	     (methods (make-vector len #f)))
	 (let loop ((i 0)
		    (plist plist))
	    (if (=fx i len)
		(let ((cmap (instantiate::JsConstructMap
			       (methods methods)
			       (props props))))
		   (instantiateJsObject
		      (cmap cmap)
		      (__proto__ __proto__)
		      (elements elements)))
		(let* ((name (cond
				((keyword? (car plist))
				 (keyword->symbol (car plist)))
				((string? (car plist))
				 (string->symbol (car plist)))
				(else
				 (car plist))))
		       (val (js-obj->jsobject (cadr plist) %this)))
		   (vector-set! props i (prop name (property-flags-default)))
		   (vector-set! elements i val)
		   (when (isa? val JsFunction) (vector-set! methods i #t))
		   (loop (+fx i 1) (cddr plist))))))))

;*---------------------------------------------------------------------*/
;*    js-jsobject->plist ...                                           */
;*---------------------------------------------------------------------*/
(define (js-jsobject->plist obj %this)
   (let ((args '()))
      (js-for-in obj
	 (lambda (p)
	    (let ((p (string->symbol (js-jsstring->string p))))
	       (set! args (cons (symbol->keyword p) args))
	       (set! args (cons (js-get obj p %this) args))))
	 %this)
      (reverse! args)))

;*---------------------------------------------------------------------*/
;*    js-jsobject->keyword-plist ...                                   */
;*---------------------------------------------------------------------*/
(define (js-jsobject->keyword-plist obj %this)
   (let ((args '()))
      (js-for-in obj
	 (lambda (p)
	    (let ((p (string->symbol (js-jsstring->string p))))
	       (set! args (cons (symbol->keyword p) args))
	       (set! args (cons (js-get obj p %this) args))))
	 %this)
      (reverse! args)))

;*---------------------------------------------------------------------*/
;*    js-jsobject->alist ...                                           */
;*---------------------------------------------------------------------*/
(define (js-jsobject->alist obj %this)
   (let ((args '()))
      (js-for-in obj
	 (lambda (p)
	    (let* ((n (js-jsstring->string p))
		   (k (string->symbol n))
		   (e (cons (string->keyword n) (js-get obj k %this))))
	       (set! args (cons e args))))
	 %this)
      (reverse! args)))

;*---------------------------------------------------------------------*/
;*    js-dsssl-args->jsargs ...                                        */
;*    -------------------------------------------------------------    */
;*    Convert all dsssl values.                                        */
;*---------------------------------------------------------------------*/
(define (js-dsssl-args->jsargs args %this)
   (let loop ((as args))
      (if (null? as)
	  args
	  (begin
	     (set-car! (cdr as) (js-obj->jsobject (cadr as) %this))
	     (loop (cddr as))))))

;*---------------------------------------------------------------------*/
;*    js-object->keyword-arguments* ...                                */
;*---------------------------------------------------------------------*/
(define (js-object->keyword-arguments* obj %this)
   
   (define (flatten lst)
      (let flatten ((lst lst)
		    (res '()))
	 (cond
	    ((null? lst)
	     (reverse! res))
	    ((isa? (car lst) JsArray)
	     (flatten (append (xml-unpack (car lst)) (cdr lst)) res))
	    (else
	     (flatten (cdr lst) (cons (car lst) res))))))

   (let ((acc '()))
      (js-for-in obj
	 (lambda (k)
	    (let ((val (js-get obj k %this))
		  (key (string->keyword (js-jsstring->string k))))
	       (if (isa? val JsArray)
		   (with-access::JsArray val (vec)
		      (let ((l (flatten (vector->list vec))))
			 (if (pair? l)
			     (set! acc (append (reverse! l) (cons key acc)))
			     (set! acc (cons* '() (cons key acc))))))
		   (set! acc (cons* val key acc)))))
	 %this)
      (reverse! acc)))

;*---------------------------------------------------------------------*/
;*    js-socket->jsobject ...                                          */
;*---------------------------------------------------------------------*/
(define (js-socket->jsobject obj %this)
   (with-access::JsGlobalObject %this (__proto__)
      (let ((sock (instantiateJsWrapper
		     (__proto__ __proto__)
		     (data #unspecified)
		     (obj obj))))
	 (js-bind! %this sock 'hostname
	    :value (js-string->jsstring (socket-hostname obj))
	    :writable #f :configurable #f
	    :hidden-class #t)
	 (js-bind! %this sock 'hostAddress
	    :value (js-string->jsstring (socket-host-address obj))
	    :writable #f :configurable #f
	    :hidden-class #t)
	 (js-bind! %this sock 'localAddress
	    :value (js-string->jsstring (socket-local-address obj))
	    :writable #f :configurable #f
	    :hidden-class #t)
	 (js-bind! %this sock 'port
	    :value (socket-port-number obj)
	    :writable #f :configurable #f
	    :hidden-class #t)
	 sock)))

;*---------------------------------------------------------------------*/
;*    js-procedure->jsobject ...                                       */
;*---------------------------------------------------------------------*/
(define (js-procedure->jsobject obj %this)
   (js-make-function %this obj (procedure-arity obj) "native"))

;*---------------------------------------------------------------------*/
;*    js-iterable->list ...                                            */
;*---------------------------------------------------------------------*/
(define (js-iterable->list obj %this)
   (cond
      ((js-array? obj)
       (jsarray->list obj %this))
      ((js-jsstring? obj)
       (js-jsstring->list obj))
      (else
       (error "js-iterable->list"
	  (format "not implemented yet \"~a\"" (typeof obj)) obj))))

;*---------------------------------------------------------------------*/
;*    js-jsobject->jsarray ::obj ...                                   */
;*---------------------------------------------------------------------*/
(define-generic (js-jsobject->jsarray o::obj %this::JsGlobalObject)
   (if (js-jsstring? o)
       (js-jsstring->jsarray o %this)
       (js-raise-type-error %this "call: not an object ~s" o)))

;*---------------------------------------------------------------------*/
;*    js-jsobject->jsarray ::JsObject ...                              */
;*---------------------------------------------------------------------*/
(define-method (js-jsobject->jsarray o::JsObject %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-symbol-iterator)
      (let ((fun (js-get o js-symbol-iterator %this))
	    (acc '()))
	 (if (isa? fun JsFunction)
	     (begin
		(js-for-of-iterator (js-call0 %this fun o) o
		   (lambda (e) (set! acc (cons e acc))) #f %this)
		(js-vector->jsarray (list->vector (reverse! acc)) %this))
	     (js-raise-type-error %this "call: not an interator ~s"
	       o)))))

;*---------------------------------------------------------------------*/
;*    fixnums? ...                                                     */
;*---------------------------------------------------------------------*/
(define-inline (fixnums? a b)
   (cond-expand
      ((and bigloo-c (config nan-tagging #f))
       (pragma::bool "INTEGERP( TAG_INT == 0 ? ((long)$1 | (long)$2) : ((long)$1 & (long)$2) )" a b))
      (else
       (and (fixnum? a) (fixnum? b)))))
