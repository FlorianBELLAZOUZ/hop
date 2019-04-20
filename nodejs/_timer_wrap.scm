;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/nodejs/_timer_wrap.scm              */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Tue May  6 15:01:14 2014                          */
;*    Last change :  Sat Apr 20 14:08:04 2019 (serrano)                */
;*    Copyright   :  2014-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Hop Timer                                                        */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __nodejs__timer-wrap

   (library hopscript)

   (import __nodejs_uv)
   
   (static (class JsTimer::JsObject
	      (worker::WorkerHopThread read-only)
	      (timer (default #f))
	      (proc (default #f))
	      (marked (default #f))))

   (export (hopjs-process-timer ::WorkerHopThread ::JsGlobalObject ::JsObject))

   (static __js_strings::vector))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    constructors                                                     */
;*---------------------------------------------------------------------*/
(define-instantiate JsTimer)

;*---------------------------------------------------------------------*/
;*    hopjs-process-timer ...                                          */
;*---------------------------------------------------------------------*/
(define (hopjs-process-timer %worker %this process)
   
   (define js-timer-prototype
      (instantiateJsObject))


   (set! __js_strings (&init!))
   (init-timer-prototype! %this js-timer-prototype)
   
   (define Timer
      (js-make-function %this 
	 (lambda (this) this)
	 0 "Timer"
	 :prototype js-timer-prototype
	 :alloc js-no-alloc
	 :construct (js-timer-construct! %worker %this process js-timer-prototype)))

   (js-bind! %this Timer (& "now")
      :value (js-make-function %this
		(lambda (this)
		   (nodejs-now %worker))
		0 "now")
      :writable #f)
   
   (with-access::JsGlobalObject %this (js-object)
      (js-alist->jsobject
	 `((Timer . ,Timer))
	 %this)))

;*---------------------------------------------------------------------*/
;*    js-timer-construct! ...                                          */
;*---------------------------------------------------------------------*/
(define (js-timer-construct! %worker %this::JsGlobalObject process js-timer-prototype)
   (lambda (_)
      (let ((obj (instantiateJsTimer
		    (__proto__ js-timer-prototype)
		    (worker (js-current-worker)))))
	 (with-access::JsTimer obj (timer)
	    (set! timer (nodejs-make-timer %worker %this process obj)))
	 obj)))

;*---------------------------------------------------------------------*/
;*    init-timer-prototype! ...                                        */
;*---------------------------------------------------------------------*/
(define (init-timer-prototype! %this::JsGlobalObject obj)
   
   (define (not-implemented name)
      (js-make-function %this
	 (lambda (this . l)
	    (error "timer_wrap" "binding not implemented" name))
	 0 name))
   
   (js-bind! %this obj (& "start")
      :value (js-make-function %this
		(lambda (this start rep)
		   (with-access::JsTimer this (timer worker)
		      (nodejs-timer-start worker timer start rep)))
		2 "start"))
   (js-bind! %this obj (& "close")
      :value (js-make-function %this
		(lambda (this)
		   (with-access::JsTimer this (timer worker)
		      (nodejs-timer-close worker timer)))
		0 "close"))
   (js-bind! %this obj (& "stop")
      :value (js-make-function %this
		(lambda (this)
		   (with-access::JsTimer this (timer worker)
		      (nodejs-timer-stop worker timer)))
		0 "stop"))
   (js-bind! %this obj (& "unref")
      :value (js-make-function %this
		(lambda (this)
		   (with-access::JsTimer this (timer worker)
		      (nodejs-timer-unref worker timer)))
		0 "unref"))

   (for-each (lambda (id)
		(js-bind! %this obj (js-ascii-name->jsstring id)
		   :value (not-implemented id)))
      '("setRepeat" "getRepeat" "again")))

;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)

