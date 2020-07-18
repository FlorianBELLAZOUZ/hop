;*=====================================================================*/
;*    /tmp/HOPNEW/hop/hopscript/boolean.scm                            */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Sep 20 10:47:16 2013                          */
;*    Last change :  Sun Feb 23 14:57:52 2020 (serrano)                */
;*    Copyright   :  2013-20 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Native Bigloo support of JavaScript booleans                     */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-15.6         */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopscript_boolean

   (library hop)

   (include "types.sch" "stringliteral.sch")
   
   (import __hopscript_types
	   __hopscript_private
	   __hopscript_public
	   __hopscript_lib
	   __hopscript_object
	   __hopscript_function
	   __hopscript_property
	   __hopscript_regexp
	   __hopscript_error)

   (export (js-init-boolean! ::JsGlobalObject)
	   (js-bool->jsBoolean::JsBoolean ::bool ::JsGlobalObject)))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    object-serializer ::JsBoolean ...                                */
;*---------------------------------------------------------------------*/
(register-class-serialization! JsBoolean
   (lambda (o ctx)
      (with-access::JsBoolean o (val) val))
   (lambda (o ctx)
      (if (isa? ctx JsGlobalObject)
	  (js-bool->jsBoolean o ctx)
	  (error "string->obvj ::JsBoolean" "Not a JavaScript context" ctx))))

;*---------------------------------------------------------------------*/
;*    js-donate ::JsBoolean ...                                        */
;*---------------------------------------------------------------------*/
(define-method (js-donate obj::JsBoolean worker::WorkerHopThread %_this)
   (with-access::WorkerHopThread worker (%this)
      (with-access::JsGlobalObject %this (js-boolean)
	 (let ((nobj (call-next-method)))
	    (with-access::JsBoolean nobj (val)
	       (with-access::JsBoolean obj ((_val val))
		  (js-object-proto-set! nobj (js-get js-boolean (& "prototype") %this))
		  (set! val (js-donate _val worker %_this))))
	    nobj))))

;*---------------------------------------------------------------------*/
;*    hop->javascript ::JsBoolean ...                                  */
;*    -------------------------------------------------------------    */
;*    See runtime/js_comp.scm in the Hop library for the definition    */
;*    of the generic.                                                  */
;*---------------------------------------------------------------------*/
(define-method (hop->javascript o::JsBoolean op compile isexpr ctx)
   (with-access::JsBoolean o (val)
      (display (if val "new Boolean(true)" "new Boolean(false)") op)))

;*---------------------------------------------------------------------*/
;*    js-init-boolean! ...                                             */
;*---------------------------------------------------------------------*/
(define (js-init-boolean! %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-boolean js-function)
      ;; local constant strings
      (unless (vector? __js_strings) (set! __js_strings (&init!)))
      
      (define js-boolean-prototype
	 (instantiateJsBoolean
	    (val #f)
	    (__proto__ (js-object-proto %this))))
      
      (define (js-boolean-alloc %this constructor::JsFunction)
	 (instantiateJsBoolean
	    (__proto__ (js-get constructor (& "prototype") %this))))
      
      ;; then, Create a HopScript string object
      (set! js-boolean
	 (js-make-function %this %js-boolean
	    (js-function-arity %js-boolean)
	    (js-function-info :name "Boolean" :len 1)
	    :__proto__ (js-object-proto js-function)
	    :prototype js-boolean-prototype
	    :alloc js-boolean-alloc
	    :construct js-boolean-construct))
      ;; now the boolean constructor is fully built,
      ;; initialize the prototype properties
      (init-builtin-boolean-prototype! %this js-boolean js-boolean-prototype)
      ;; bind Boolean in the global object
      (js-bind! %this %this (& "Boolean")
	 :configurable #f :enumerable #f :value js-boolean
	 :hidden-class #t)
      js-boolean))

;*---------------------------------------------------------------------*/
;*    %js-boolean ...                                                  */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-15.6.1.1     */
;*---------------------------------------------------------------------*/
(define (%js-boolean this value)
   (js-toboolean value))

;*---------------------------------------------------------------------*/
;*    js-boolean-construct ...                                         */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-15.6.2       */
;*---------------------------------------------------------------------*/
(define (js-boolean-construct this::JsBoolean arg)
   (with-access::JsBoolean this (val)
      (set! val (js-toboolean arg)))
   this)

;*---------------------------------------------------------------------*/
;*    js-valueof ::JsBoolean ...                                       */
;*---------------------------------------------------------------------*/
(define-method (js-valueof this::JsBoolean %this)
   this)
   
;*---------------------------------------------------------------------*/
;*    init-builtin-boolean-prototype! ...                              */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-15.6.3.1     */
;*---------------------------------------------------------------------*/
(define (init-builtin-boolean-prototype! %this::JsGlobalObject js-boolean obj)

   (define (js-cast-boolean this shape)
      (cond
	 ((boolean? this) this)
	 ((isa? this JsBoolean) (with-access::JsBoolean this (val) val))
	 (else (js-raise-type-error %this "Not a boolean ~a"
		  (if shape (shape this) this)))))
   
   ;; prototype fields
   (js-bind! %this obj (& "constructor")
      :value js-boolean
      :enumerable #f
      :hidden-class #t)
   ;; toString
   (js-bind! %this obj (& "toString")
      :value (js-make-function %this
		(lambda (this)
		   (let ((val (js-cast-boolean this typeof)))
		      (if val
			  (js-string->jsstring "true")
			  (js-string->jsstring "false"))))
		(js-function-arity 0 0)
		(js-function-info :name "toString" :len 0))
      :enumerable #f
      :hidden-class #t)
   ;; valueOf
   (js-bind! %this obj (& "valueOf")
      :value (js-make-function %this
		(lambda (this)
		   (js-cast-boolean this #f))
		(js-function-arity 0 0)
		(js-function-info :name "valueOf" :len 0))
      :enumerable #f
      :hidden-class #t))
      
;*---------------------------------------------------------------------*/
;*    js-bool->jsBoolean ...                                           */
;*---------------------------------------------------------------------*/
(define (js-bool->jsBoolean val::bool %this::JsGlobalObject)
   (with-access::JsGlobalObject %this (js-boolean)
      (js-new1 %this js-boolean val)))

;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)

