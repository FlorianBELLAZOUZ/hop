;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/hopreplay/parseargs.scm             */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Fri Nov 12 13:32:52 2004                          */
;*    Last change :  Mon May 13 19:18:05 2019 (serrano)                */
;*    Copyright   :  2004-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    HOPREPLAY command line parsing                                   */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module hoprp_parseargs

   (library hop)
   
   (import  hoprp_param
	    hoprp_login)
   
   (export  (parse-args ::pair-nil)
	    (hoprp-load-rc ::bstring)))

;*---------------------------------------------------------------------*/
;*    parse-args ...                                                   */
;*---------------------------------------------------------------------*/
(define (parse-args args)
   (let ((rc-file #unspecified)
	 (login #f)
	 (loadp #t)
	 (logfiles '()))
      (args-parse (cdr args)
         ((("-h" "--help") (help "This message"))
	  (print "Hopreplay v" (hop-version))
	  (print "usage: hopreplay [options] logfile")
	  (newline)
          (args-parse-usage #f)
          (exit 0))
         (("--options" (help "Display the Hop options and exit"))
          (args-parse-usage #t)
          (exit 0))
         (("--version" (help "Print the version and exit"))
          (print (hop-name) (hop-version))
          (exit 0))
	 (("-q" (help "Do not load an init file"))
	  (set! loadp #f))
	 (("--rc-file" ?file (help "Load alternate rc file"))
	  (set! rc-file file))
	 (("--rc-dir" ?dir (help "Set rc directory"))
	  (hop-rc-directory-set! dir))
	 (("--cache-dir" ?dir (help "Set cache directory"))
	  (hop-cache-directory-set! dir))
         (("-v?level" (help "Increase or set verbosity level (-v0 crystal silence)"))
          (if (string=? level "")
	      (hop-verbose-set! (+fx 1 (hop-verbose)))
	      (hop-verbose-set! (string->integer level))))
         (("-g?level" (help "Increase or set debug level"))
          (if (string=? level "")
	      (bigloo-debug-set! (+fx 1 (bigloo-debug)))
	      (bigloo-debug-set! (string->integer level))))
	 (("-w?level" (help "Increase or set warning level (-w0 no warning)"))
          (if (string=? level "")
	      (bigloo-warning-set! (+fx 1 (bigloo-warning)))
	      (bigloo-warning-set! (string->integer level))))
	 ((("-l" "--login") ?user (help "Specify user log in"))
	  (set! login user))
	 ((("-t" "--threads") ?num (help "Number of threads"))
	  (hoprp-threads-num-set! (string->integer num)))
	 ((("-L" "--loop") (help "Infinite loop"))
	  (hoprp-loop-set! #t))
	 ((("-H" "--host") ?host (help (format "Host name (default: localhost)")))
	  (hoprp-host-set! host))
	 ((("-p" "--port") ?port (help (format "Port number (default: 8080)")))
	  (hoprp-port-set! (string->integer port)))
	 (("-?dummy")
	  (args-parse-usage #f)
	  (exit 1))
	 (else
	  (set! logfiles (cons else logfiles))))
      (when login (login! login))
      (when loadp
	 (if (string? rc-file)
	     (%hoprp-load-rc rc-file)
	     (let ((path (make-file-name (hop-rc-directory) (hoprp-rc-file))))
		(if (file-exists? path)
		    (%hoprp-load-rc path)
		    (%hoprp-load-rc (make-file-name (hop-etc-directory) (hop-rc-file)))))))
      (reverse! logfiles)))

;*---------------------------------------------------------------------*/
;*    %hoprp-load-rc ...                                               */
;*---------------------------------------------------------------------*/
(define (%hoprp-load-rc path)
   (if (string? path)
       (when (file-exists? path)
	  (hop-verb 2 "Loading `" path "'...\n")
	  (hop-load path))))
      
;*---------------------------------------------------------------------*/
;*    hoprp-load-rc ...                                                */
;*---------------------------------------------------------------------*/
(define (hoprp-load-rc file)
   (let ((path (make-file-name (hop-rc-directory) file)))
      (when (file-exists? path)
	 (%hoprp-load-rc path))))
      

