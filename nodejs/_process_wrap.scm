;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/nodejs/_process_wrap.scm            */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Oct 17 17:07:03 2014                          */
;*    Last change :  Fri Apr 12 18:05:46 2019 (serrano)                */
;*    Copyright   :  2014-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Nodejs child processes bindings                                  */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __nodejs__process-wrap

   (library hopscript)

   (include "nodejs_types.sch")

   (import  __nodejs_uv
	    __nodejs_process)

   (export (process-process-wrap ::WorkerHopThread ::JsGlobalObject ::JsObject)))

;*---------------------------------------------------------------------*/
;*    &begin!                                                          */
;*---------------------------------------------------------------------*/
(define __js_strings (&begin!))

;*---------------------------------------------------------------------*/
;*    process-process-wrap ...                                         */
;*---------------------------------------------------------------------*/
(define (process-process-wrap %worker %this process)
   
   (define process-prototype
      (with-access::JsGlobalObject %this (js-object)
	 (js-new %this js-object)))

   (set! __js_strings (&init!))
   
   ;; bind the methods of the prototype object
   (js-put! process-prototype (& "spawn")
      (js-make-function %this 
	 (lambda (this options)
	    (nodejs-process-spawn %worker %this process this options))
	 1 "spawn")
      #f %this)
   
   (js-put! process-prototype (& "kill")
      (js-make-function %this 
	 (lambda (this pid)
	    (nodejs-process-kill %worker %this process this pid))
	 1 "kill")
      #f %this)
   
   (js-put! process-prototype (& "close")
      (js-make-function %this
	 (lambda (this cb)
	    (nodejs-close %worker %this process this cb))
	 1 "close")
      #f %this)
   
   (js-put! process-prototype (& "ref")
      (js-make-function %this
	 (lambda (this)
	    (with-access::JsHandle this (handle)
	       (nodejs-ref handle %worker)))
	 0 "ref")
      #f %this)
	    
   (js-put! process-prototype (& "unref")
      (js-make-function %this
	 (lambda (this)
	    (with-access::JsHandle this (handle)
	       (nodejs-unref handle %worker)))
	 0 "unref")
      #f %this)
   
   (with-access::JsGlobalObject %this (js-object)
      (js-alist->jsobject
	 `((Process . ,(js-make-function %this
			  (lambda (this) this)
			  1 "Process"
			  :alloc (lambda (%this o)
				    (instantiateJsHandle
				       (handle (nodejs-new-process))
				       (__proto__ process-prototype))))))
	 %this)))



;*---------------------------------------------------------------------*/
;*    &end!                                                            */
;*---------------------------------------------------------------------*/
(&end!)

