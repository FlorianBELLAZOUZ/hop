;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/runtime/weblets.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Erick Gallesio                                    */
;*    Creation    :  Sat Jan 28 15:38:06 2006 (eg)                     */
;*    Last change :  Mon Apr 20 06:27:44 2020 (serrano)                */
;*    Copyright   :  2004-20 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Weblets Management                                               */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hop_weblets

   (include "xml.sch"
            "verbose.sch")
   
   (import __hop_configure
	   __hop_param
	   __hop_types
	   __hop_xml-types
	   __hop_xml
	   __hop_service
	   __hop_misc
	   __hop_read
	   __hop_user
	   __hop_json)
   
   (static  (abstract-class %autoload
	       (path::bstring read-only)
	       (pred::procedure read-only))

	    (class %autoload-file::%autoload
	       (loaded::bool (default #f))
	       (hooks::pair-nil read-only (default '()))
	       (mutex::mutex (default (make-mutex "autoload-file"))))

	    (class %autoload-incompatible::%autoload
	       (name::bstring read-only)
	       (info::pair-nil read-only)))
   
   (export  (find-weblets-in-directory ::bstring)
	    (weblet-compatible?::bool ::pair-nil)
	    (reset-autoload!)
	    (get-autoload-directories::pair-nil)
	    (get-autoload-weblet-directories::pair-nil)
	    (hop-load-hz ::bstring)
	    (hop-load-weblet ::bstring)
	    (install-autoload-weblets! ::pair-nil)
	    (autoload-prefix::procedure ::bstring)
	    (autoload ::bstring ::procedure . hooks)
	    (autoload-filter ::http-request)
	    (autoload-force-load! ::bstring)
	    (get-weblet-info::pair-nil ::bstring)
	    (get-weblets-zeroconf::pair-nil)
	    (weblet-version-rx)))

;*---------------------------------------------------------------------*/
;*    weblet-version-rx ...                                            */
;*---------------------------------------------------------------------*/
(define version-rx
   (pregexp "[0-9]+.[0-9]+.[0-9]+(?:[-][0-9]+)?"))
   
(define (weblet-version-rx)
   version-rx)
   
;*---------------------------------------------------------------------*/
;*    find-weblets-in-directory ...                                    */
;*---------------------------------------------------------------------*/
(define (find-weblets-in-directory dir)
   
   (define (versions dir)
      ;; scans dir to find version sub-directories to find ordered
      ;; version numbers
      (sort (lambda (x y) (>fx (string-natural-compare3 x y) 0))
	 (filter! (lambda (f) (pregexp-match (weblet-version-rx) f))
	    (directory->list dir))))
   
   (define (search pred lst)
      (when (pair? lst)
	 (or (pred (car lst)) (search pred (cdr lst)))))
   
   (define (get-weblet-details dir name)
      (let* ((infos (get-weblet-info dir))
	     (main (assoc 'main infos)))
	 (if main
	     (let ((weblet (make-file-name dir (cadr main))))
		(when (file-exists? weblet)
		   `((weblet ,weblet) (prefix ,dir) (name ,name) ,@infos)))
	     (let ((weblet (make-file-name dir (string-append name ".hop"))))
		(if (file-exists? weblet)
		    `((weblet ,weblet) (prefix ,dir) (name ,name) ,@infos)
		    (let ((weblet (make-file-name dir (string-append name ".js"))))
		       (if (file-exists? weblet)
			   `((weblet ,weblet) (prefix ,dir) (name ,name) ,@infos)
			   (if (file-exists? (make-file-name dir name))
			       (get-weblet-details (make-file-name dir name)  name)
			       (search (lambda (v)
					  (get-weblet-details
					     (make-file-name dir v) name))
				  (versions dir))))))))))
   
   (let loop ((files (directory->list dir))
	      (res '()))
      (if (null? files)
	  res
	  (let* ((name (car files))
		 (web (get-weblet-details (make-file-name dir name) name)))
	     (if web
		 (loop (cdr files) (cons web res))
		 (loop (cdr files) res))))))

;*---------------------------------------------------------------------*/
;*    weblet-compatible? ...                                           */
;*---------------------------------------------------------------------*/
(define (weblet-compatible? info)
   (or (null? info)
       (and (weblet-version-compatible? info)
	    (weblet-features-supported? info))))

;*---------------------------------------------------------------------*/
;*    weblet-incomatible-error-msg ...                                 */
;*---------------------------------------------------------------------*/
(define (weblet-incomatible-error-msg info)
   (cond
      ((not (weblet-version-compatible? info))
       (weblet-version-error-msg info))
      ((not (weblet-features-supported? info))
       (weblet-features-error-msg info))
      (else
       "incompatible weblet")))
      
;*---------------------------------------------------------------------*/
;*    weblet-version-compatible? ...                                   */
;*---------------------------------------------------------------------*/
(define (weblet-version-compatible? x)
   
   (define (cmpversion version cmp)
      (or (not (pair? version))
	  (not (string? (cadr version)))
	  (string=? (cadr version) "")
	  (cmp (hop-version) (cadr version))))
   
   (and (cmpversion (assq 'minhop x) string>=?)
	(cmpversion (assq 'maxhop x) string<=?)))

;*---------------------------------------------------------------------*/
;*    weblet-version-error-msg ...                                     */
;*---------------------------------------------------------------------*/
(define (weblet-version-error-msg x)
   (format "Hop ~s incompatible with version requirements min: ~a, max: ~a"
	   (hop-version)
	   (let ((c (assq 'minhop x)))
	      (if (pair? c) (cadr c) "*"))
	   (let ((c (assq 'maxhop x)))
	      (if (pair? c) (cadr c) "*"))))

;*---------------------------------------------------------------------*/
;*    weblet-features-supported? ...                                   */
;*---------------------------------------------------------------------*/
(define (weblet-features-supported? x)
   (let ((features (assq 'features x)))
      (or (not features) (every eval-srfi? (cadr features)))))

;*---------------------------------------------------------------------*/
;*    weblet-features-error-msg ...                                    */
;*---------------------------------------------------------------------*/
(define (weblet-features-error-msg x)
   (format "Hop does not support features: ~l"
	   (filter (lambda (f)
		      (not (eval-srfi? f)))
		   (cadr (assq 'features x)))))

;*---------------------------------------------------------------------*/
;*    get-weblet-info ...                                              */
;*---------------------------------------------------------------------*/
(define (get-weblet-info wdir::bstring)
   
   (define (normalize-json l)
      (if (list? l)
	  (map (lambda (a)
		  (match-case a
		     ((?a . ?d) (list a d))
		     (else (list #f #f))))
	     l)
	  '()))
   
   (let ((file (make-file-path wdir "etc" "weblet.info")))
      (if (file-exists? file)
	  `((info "weblet.info")
	    (path ,wdir)
	    ,@(call-with-input-file file read))
	  (let ((pkg (make-file-path wdir "package.json")))
	     (if (file-exists? pkg)
		 `((info "package.json")
		   (path ,wdir)
		   ,@(normalize-json
			(call-with-input-file pkg javascript->obj)))
		 '())))))

;*---------------------------------------------------------------------*/
;*    *weblet-table* ...                                               */
;*---------------------------------------------------------------------*/
(define *weblet-table* (make-hashtable))

;*---------------------------------------------------------------------*/
;*    *weblet-lock* ...                                                */
;*---------------------------------------------------------------------*/
(define *weblet-lock* (make-mutex "weblets"))

;*---------------------------------------------------------------------*/
;*    *weblet-autoload-dirs* ...                                       */
;*---------------------------------------------------------------------*/
(define *weblet-autoload-dirs* '())

;*---------------------------------------------------------------------*/
;*    reset-autoload! ...                                              */
;*---------------------------------------------------------------------*/
(define (reset-autoload!)
   (let ((warn (bigloo-warning)))
      (unwind-protect
	 (begin
	    (bigloo-warning-set! 0)
	    (install-autoload-weblets! *weblet-autoload-dirs*))
	 (bigloo-warning-set! warn))))

;*---------------------------------------------------------------------*/
;*    get-autoload-directories ...                                     */
;*---------------------------------------------------------------------*/
(define (get-autoload-directories)
   *weblet-autoload-dirs*)

;*---------------------------------------------------------------------*/
;*    hop-load-hz ...                                                  */
;*---------------------------------------------------------------------*/
(define (hop-load-hz path)
   (let ((p (open-input-gzip-file path)))
      (if (input-port? p)
	  (unwind-protect
	     (let* ((tmp (make-file-name (os-tmp) "hop"))
		    (file (car (untar p :directory tmp)))
		    (base (substring file
			     (+fx (string-length tmp) 1)
			     (string-length file)))
		    (dir (dirname base))
		    (name (if (string=? dir ".") base dir))
		    (src (make-file-path tmp name (string-append name ".hop"))))
		(hop-load-weblet src))
	     (close-input-port p))
	  (error "hop-load-hz" "Cannot find HZ file" path))))

;*---------------------------------------------------------------------*/
;*    hop-load-weblet ...                                              */
;*---------------------------------------------------------------------*/
(define (hop-load-weblet path)
   (let* ((dir (dirname path))
	  (name (basename (prefix path))))
      (if (file-exists? path)
	  (let ((winfo (get-weblet-info dir))
		(url (string-append "/hop/" name)))
	     (cond
		((not (weblet-version-compatible? winfo))
		 (error "hop-load-weblet"
			(weblet-version-error-msg winfo)
			name))
		((not (weblet-features-supported? winfo))
		 (error "hop-load-weblet"
			(weblet-features-error-msg winfo)
			name))
		(else
		 (hop-load-once path)
		 (install-weblet-dashboard! name dir winfo url))))
	  (error "hop-load-weblet" "Cannot find HOP source" path))))

;*---------------------------------------------------------------------*/
;*    install-weblet-dashboard! ...                                    */
;*---------------------------------------------------------------------*/
(define (install-weblet-dashboard! name dir winfo url)
   
   (define (add-dashboard-applet! name icon svc)
      (unless (pair? (assoc name (hop-dashboard-weblet-applets)))
	 (hop-dashboard-weblet-applets-set!
	  (cons (list name icon svc) (hop-dashboard-weblet-applets)))))

   (unless (member name (hop-dashboard-weblet-disabled-applets))
      ;; the user does not want of this weblet
      (let ((dashboard (assq 'dashboard winfo)))
	 ;; dashboard declaration
	 (if (pair? dashboard)
	     ;; a customized dashboard
	     (for-each (lambda (d)
			  (match-case d
			     ((?i ?svc)
			      (let ((p (make-file-path dir "etc" i)))
				 (add-dashboard-applet! dir p svc)))
			     ((and ?i (? string?))
			      (let* ((p (make-file-path dir "etc" i))
				     (svc (string-append url "/dashboard")))
				 (add-dashboard-applet! name i svc)))
			     (else
			      (warning "autoload-weblets"
				       "bad dashboard declaration"
				       d))))
		       (cdr dashboard))
	     ;; is there a dashboard icon for a regular an applet?
	     (let ((icon (make-file-path dir "etc" "dashboard.png")))
		(when (file-exists? icon)
		   (let ((svc (string-append url "/dashboard")))
		      (add-dashboard-applet! name icon svc))))))))

;*---------------------------------------------------------------------*/
;*    install-autoload-weblets! ...                                    */
;*---------------------------------------------------------------------*/
(define (install-autoload-weblets! dirs)

   (define (install-autoload-prefix path url)
      (hop-verb 4 (hop-color 1 "" "AUTOLOAD") " " path " for " url "\n")
      (autoload path (autoload-prefix url)))
   
   (define (warn name opath npath)
      (when (>= (bigloo-warning) 1)
	 (warning name
	    (format "autoload already installed, ignoring \"~a\"" npath))))

   (define (maybe-autoload x)
      (let ((cname (assq 'name x)))
	 (if (pair? cname)
	     (let* ((name (cadr cname))
		    (prefix (cadr (assq 'prefix x)))
		    (svc (let ((c (assq 'service x)))
			    (if (and (pair? c) (symbol? (cadr c)))
				(symbol->string (cadr c))
				name)))
		    (url (make-url-name (hop-service-base) svc))
		    (path (cadr (assq 'weblet x)))
		    (autopred (assq 'autoload x))
		    (rc (assq 'rc x))
		    (zc (assq 'zeroconf x))
		    (opath (hashtable-get *weblet-table* svc)))
		;; dashboard setup
		(install-weblet-dashboard! name prefix x url)
		;; rc setup
		(when (pair? rc) (eval (cadr rc)))
		;; zeroconf
		(when (pair? zc)
		   (hop-verb 2 "zeroconf publish " name " "
		      (hop-color 3 "" path)
		      "\n")
		   (weblet-zeroconf-add! name (cdr zc)))
		;; autoload per say
		(cond
		   ((string? opath)
		    (warn name opath path))
		   ((not (weblet-compatible? x))
		    (when (> (bigloo-warning) 1)
		       (warning name (weblet-incomatible-error-msg x)))
		    (autoload-incompatible path (autoload-prefix url) name x))
		   ((pair? autopred)
		    (when (cadr autopred)
		       (hashtable-put! *weblet-table* name path)
		       (hop-verb 3 "Setting autoload " (hop-color 4 "" path)
			  " when " (cadr autopred) "\n")
		       (autoload path (eval (cadr autopred)))))
		   (else
		    (hashtable-put! *weblet-table* name svc)
		    (install-autoload-prefix path url))))
	     (let ((info (assq 'info x)))
		(warning "autoload-weblets"
		   (format "Illegal weblet ~s file"
		      (if (pair? info) (cadr info) "etc/weblet.info"))
		   x)))))
   
   ;; since autoload are likely to be installed before the scheduler
   ;; starts, the lock above is unlikely to be useful.
   (synchronize *weblet-lock*
      (set! *weblet-autoload-dirs* dirs)
      (for-each (lambda (dir)
		   (for-each maybe-autoload (find-weblets-in-directory dir)))
	 dirs)))

;*---------------------------------------------------------------------*/
;*    autoload-prefix ...                                              */
;*    -------------------------------------------------------------    */
;*    Builds a predicate that matches iff the request path is a        */
;*    prefix of STRING.                                                */
;*---------------------------------------------------------------------*/
(define (autoload-prefix path)
   (let ((lp (string-length path)))
      (lambda (req)
	 (with-access::http-request req (abspath)
	    (and (substring-at? abspath path 0)
		 (let ((la (string-length abspath)))
		    (or (=fx la lp) (char=? (string-ref abspath lp) #\/))))))))

;*---------------------------------------------------------------------*/
;*    *autoload-mutex* ...                                             */
;*---------------------------------------------------------------------*/
(define *autoload-mutex* (make-mutex "autoload"))

;*---------------------------------------------------------------------*/
;*    *autoloads* ...                                                  */
;*---------------------------------------------------------------------*/
(define *autoloads* '())
(define *autoloads-loaded* '())

;*---------------------------------------------------------------------*/
;*    get-autoload-weblet-directories ...                              */
;*---------------------------------------------------------------------*/
(define (get-autoload-weblet-directories)
   (map (lambda (o)
	   (with-access::%autoload o (path)
	      path))
	*autoloads*))

;*---------------------------------------------------------------------*/
;*    autoload ...                                                     */
;*---------------------------------------------------------------------*/
(define (autoload file pred . hooks)
   (synchronize *autoload-mutex*
      (let ((qfile (find-file/path file (hop-path))))
	 (cond
	    ((not (and (string? qfile) (file-exists? qfile)))
	     (error "autoload-add!" "Can't find autoload file" file))
	    ((find (lambda (a::%autoload)
		      (with-access::%autoload a (path)
			 (string=? path qfile)))
		*autoloads*)
	     =>
	     (lambda (a::%autoload)
		(when (isa? a %autoload-file)
		   (with-access::%autoload-file a ((apred pred) (ahooks hooks))
		      (unless (and (equal? apred pred) (equal? ahooks hooks))
			 (warning "autoload-add!"
			    "Autoload already registered" file))))))
	    (else
	     (let ((al (instantiate::%autoload-file
			  (path qfile)
			  (pred pred)
			  (hooks hooks))))
		(set! *autoloads* (cons al *autoloads*))))))))

;*---------------------------------------------------------------------*/
;*    autoload-incompatible ...                                        */
;*---------------------------------------------------------------------*/
(define (autoload-incompatible file pred name info)
   (synchronize *autoload-mutex*
      (let ((qfile (find-file/path file (hop-path))))
	 (if (not (and (string? qfile) (file-exists? qfile)))
	     (error "autoload-add!" "Can't find autoload file" file)
	     (let ((al (instantiate::%autoload-incompatible
			  (path qfile)
			  (pred pred)
			  (name name)
			  (info info))))
		(set! *autoloads* (cons al *autoloads*)))))))

;*---------------------------------------------------------------------*/
;*    autoload-load! ...                                               */
;*---------------------------------------------------------------------*/
(define-generic (autoload-load! a::%autoload req))

;*---------------------------------------------------------------------*/
;*    autoload-load! ::%autoload-file ...                              */
;*---------------------------------------------------------------------*/
(define-method (autoload-load! a::%autoload-file req)
   (with-access::%autoload-file a (path hooks loaded mutex)
      (synchronize mutex
	 (unless loaded
	    (hop-verb 1 (hop-color req req " AUTOLOADING") ": " path "\n")
	    ;; load the autoloaded file
	    (with-handler
	       (lambda (e)
		  (raise
		     (instantiate::&hop-autoload-error
			(proc "autoload-load!")
			(msg path)
			(obj e))))
	       (hop-load-modified path))
	    ;; execute the hooks
	    (for-each (lambda (h) (h req)) hooks)
	    (hop-verb 2 (hop-color req req " AUTOLOAD COMPLETE") ": " path "\n")
	    (set! loaded #t)))))

;*---------------------------------------------------------------------*/
;*    autoload-load! ::%autoload-incompatible ...                      */
;*---------------------------------------------------------------------*/
(define-method (autoload-load! a::%autoload-incompatible req)
   (with-access::%autoload-incompatible a (name info)
      (raise
       (instantiate::&hop-autoload-error
	  (proc "autoload-load")
	  (msg (weblet-incomatible-error-msg info))
	  (obj name)))))

;*---------------------------------------------------------------------*/
;*    autoload-filter ...                                              */
;*    -------------------------------------------------------------    */
;*    This filter is no longer registered as is. It is now invoked by  */
;*    the service-filter, when no service matches a HOP url.           */
;*---------------------------------------------------------------------*/
(define (autoload-filter req)
   (let loop ((al *autoloads*))
      (unless (null? al)
	 (with-access::%autoload (car al) (pred)
	    (if (pred req)
		(begin
		   ;; the autoload cannot be removed until the weblet
		   ;; is fully loaded, otherwise parallel requests to the
		   ;; autoloaded service will raise a service not found error
		   (autoload-load! (car al) req)
		   ;; add all the file associated with the autoload in
		   ;; the service path table (see __hop_service).
		   (with-access::%autoload (car al) (path)
		      (service-etc-path-table-fill! path))
		   ;; remove the autoaload (once loaded)
		   (synchronize *autoload-mutex*
		      (set! *autoloads* (remq (car al) *autoloads*))
		      (set! *autoloads-loaded* (cons (car al) *autoloads-loaded*)))
		   #t)
		(loop (cdr al)))))))

;*---------------------------------------------------------------------*/
;*    autoload-loaded? ...                                             */
;*---------------------------------------------------------------------*/
(define (autoload-loaded? req)
   (synchronize *autoload-mutex*
      (let loop ((al *autoloads-loaded*))
	 (cond
	    ((null? al) #f)
	    ((with-access::%autoload (car al) (pred) (pred req)) #t)
	    (else (loop (cdr al)))))))

;*---------------------------------------------------------------------*/
;*    autoload-force-load! ...                                         */
;*---------------------------------------------------------------------*/
(define (autoload-force-load! path)
   (let ((req (instantiate::http-server-request
		 #;(user (anonymous-user))
		 #;(localclientp #t)
		 (port (hop-default-port))
		 (path path)
		 (abspath path))))
      (or (autoload-filter req) (autoload-loaded? req))))

;*---------------------------------------------------------------------*/
;*    *weblets-zeroconf* ...                                           */
;*---------------------------------------------------------------------*/
(define *weblets-zeroconf* '())

;*---------------------------------------------------------------------*/
;*    weblet-zeroconf-add! ...                                         */
;*---------------------------------------------------------------------*/
(define (weblet-zeroconf-add! name zc)

   (define (already? name zsvc)
      (find (lambda (s)
	       (string=? (cadr s) name))
	 *weblets-zeroconf*))

   (if (already? name *weblets-zeroconf*)
       (when (>= (bigloo-warning) 1)
	  (warning "zeroconf" 
	     (format
		"\"~a\" already published (-v3 for extra info)"
		name)))
       (with-handler
	  (lambda (e)
	     (exception-notify e))
	  (for-each (lambda (z)
		       (match-case z
			  (((and (? string?) ?type))
			   (set! *weblets-zeroconf*
			      (cons `(:name ,name :type ,type
					:port ,(hop-default-port))
				 *weblets-zeroconf*)))
			  (((and (? string?) ?type) ?port . ?rest)
			   (set! *weblets-zeroconf*
			      (cons `(:name ,name :type ,type
					:port ,(if (integer? port)
						   port
						   (hop-default-port))
					,@rest)
				 *weblets-zeroconf*)))))
	     zc))))

;*---------------------------------------------------------------------*/
;*    get-weblets-zeroconf ...                                         */
;*---------------------------------------------------------------------*/
(define (get-weblets-zeroconf)
   *weblets-zeroconf*)
   
