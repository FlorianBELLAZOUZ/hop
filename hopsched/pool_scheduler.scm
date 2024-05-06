;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/src/pool_scheduler.scm              */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Tue Feb 26 07:03:15 2008                          */
;*    Last change :  Wed Feb 15 14:02:52 2023 (serrano)                */
;*    Copyright   :  2008-23 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Pool scheduler                                                   */
;*    -------------------------------------------------------------    */
;*    The characteristics of this scheduler are:                       */
;*      - an accept is handled by a single thread extracted from the   */
;*        pool.                                                        */
;*      - on completion the thread is stored in the pool.              */
;*      - on heavy load the new request waits for an old request to    */
;*        complete.                                                    */
;*    This scheduler is a little bit more complex and smarter than     */
;*    the one-to-one scheduler but it cannot handle more than SIZE     */
;*    simultaneous requests.                                           */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module hopsched_scheduler-pool

   (library hop)
   
   (import  hopsched_scheduler)

   (export  (class &stack-overflow::&error))
   
   (export  (class pool-scheduler::row-scheduler
	       (mutex::mutex read-only (default (make-mutex)))
	       (condv::condvar read-only (default (make-condition-variable)))
	       (nfree::int (default 0))
	       (free::pair-nil (default '()))
	       (naccept::int (default 0)))))

;*---------------------------------------------------------------------*/
;*    scheduler-init! ::pool-scheduler ...                             */
;*---------------------------------------------------------------------*/
(define-method (scheduler-init! scd::pool-scheduler)
   (with-access::pool-scheduler scd (size free nfree)
      (set! free (map! (lambda (x) (make-pool-thread scd)) (make-list size)))
      (set! nfree size)
      scd))

;*---------------------------------------------------------------------*/
;*    scheduler-stat ::pool-scheduler ...                              */
;*---------------------------------------------------------------------*/
(define-method (scheduler-stat scd::pool-scheduler)
   (with-access::pool-scheduler scd (size naccept mutex)
      (synchronize mutex
	 (format " (~a/~a)" (-fx size naccept) size))))

;*---------------------------------------------------------------------*/
;*    scheduler-load ::pool-scheduler ...                              */
;*---------------------------------------------------------------------*/
(define-method (scheduler-load scd::pool-scheduler)
   (with-access::pool-scheduler scd (naccept size mutex)
      (synchronize mutex
	 (flonum->fixnum
	    (*fl 100.
	       (/fl (fixnum->flonum (-fx size naccept))
		  (fixnum->flonum size)))))))

;*---------------------------------------------------------------------*/
;*    spawn ::pool-scheduler ...                                       */
;*---------------------------------------------------------------------*/
(define-method (spawn scd::pool-scheduler p . args)
   (with-access::pool-scheduler scd ((smutex mutex) condv free nfree)
      (let ((thread #f))
	 (synchronize smutex
	    (let loop ()
	       (unless (pair? free)
		  ;; we have to wait for a thread to complete
		  (condition-variable-wait! condv smutex)
		  (loop)))
	    (set! thread (car free))
	    (with-access::scdthread thread (userdata)
	       (set! userdata free)
	       (set! free (cdr free))
	       (set! nfree (-fx nfree 1))))
	 (with-access::scdthread thread (proc mutex condv)
	    (set! proc (lambda (s t) (apply p s t args)))
	    (synchronize mutex
	       (condition-variable-signal! condv))
	    thread))))

;*---------------------------------------------------------------------*/
;*    spawn5 ::pool-scheduler ...                                      */
;*---------------------------------------------------------------------*/
(define-method (spawn5 scd::pool-scheduler p a0 a1 a2 a3 a4)
   (with-access::pool-scheduler scd ((smutex mutex) condv free nfree)
      (let ((thread #f))
	 (synchronize smutex
	    (let loop ()
	       (unless (pair? free)
		  ;; we have to wait for a thread to complete
		  (condition-variable-wait! condv smutex)
		  (loop)))
	    (set! thread (car free))
	    (with-access::scdthread thread (userdata)
	       (set! userdata free)
	       (set! free (cdr free))
	       (set! nfree (-fx nfree 1))))
	 (with-access::scdthread thread (proc mutex condv)
	    (set! proc (lambda (s t) (p s t a0 a1 a2 a3 a4)))
	    (synchronize mutex
	       (condition-variable-signal! condv))
	    thread))))

;*---------------------------------------------------------------------*/
;*    pool-thread-body ...                                             */
;*---------------------------------------------------------------------*/
(define (pool-thread-body t)
   (with-access::scdthread t (proc userdata mutex condv scheduler)
      (signal sigsegv
	 (lambda (n)
	    (raise
	       (instantiate::&stack-overflow
		  (proc "hop")
		  (msg "Stack overflow")
		  (obj #f)))))
      (synchronize mutex
	 (let loop ()
	    (condition-variable-wait! condv mutex)
	    ;; complete the demanded task
	    (with-handler
	       (make-scheduler-error-handler t)
	       (proc scheduler t))
	    ;; go back to the free pool
	    (with-access::pool-scheduler scheduler ((smutex mutex)
						    (scondv condv)
						    free nfree)
	       (synchronize smutex
		  (set-cdr! userdata free)
		  (set! free userdata)
		  (set! nfree (+fx nfree 1))
		  (condition-variable-signal! scondv))
	       (loop))))))
   
;*---------------------------------------------------------------------*/
;*    make-pool-thread ...                                             */
;*---------------------------------------------------------------------*/
(define (make-pool-thread scd)
   (letrec ((t (instantiate::scdthread
		  (name (gensym 'pool-scheduler))
		  (scheduler scd)
		  (body (lambda () (pool-thread-body t))))))
      (thread-start-joinable! t)
      t))
		   
		   
