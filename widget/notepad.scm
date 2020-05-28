;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/widget/notepad.scm                  */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Thu Aug 18 10:01:02 2005                          */
;*    Last change :  Tue May  7 12:03:13 2019 (serrano)                */
;*    Copyright   :  2005-19 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    The HOP implementation of notepads.                              */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __hopwidget-notepad

   (library hop)

   (static  (class xml-nphead-element::xml-element)
	    (class xml-nptabhead-element::xml-element)
	    (class xml-nptab-element::xml-element
	       (idtab::bstring read-only)
	       (head::xml-nptabhead-element read-only)
	       (onselect read-only)
	       klass::bstring ))
   
   (export  (<NOTEPAD> . ::obj)
	    (<NPHEAD> . ::obj)
	    (<NPTAB> . ::obj)
	    (<NPTABHEAD> . ::obj)))

;*---------------------------------------------------------------------*/
;*    object-serializer ::html-foldlist ...                            */
;*---------------------------------------------------------------------*/
(define (serialize o ctx)
   (let ((p (open-output-string)))
      (obj->javascript-expr o p ctx)
      (close-output-port p)))

(define (unserialize o ctx)
   o)
      
(register-class-serialization! xml-nphead-element serialize unserialize)
(register-class-serialization! xml-nptabhead-element serialize unserialize)
(register-class-serialization! xml-nptab-element serialize unserialize)

;*---------------------------------------------------------------------*/
;*    <NOTEPAD> ...                                                    */
;*    -------------------------------------------------------------    */
;*    See __hop_css for HSS types.                                     */
;*---------------------------------------------------------------------*/
(define-tag <NOTEPAD> ((id #unspecified string)
		       (%context #f)
		       (class #unspecified string)
		       (history #unspecified)
		       (onchange #f)
		       (%location #f)
		       (attrs)
		       body)
   (let ((id (xml-make-id id 'NOTEPAD))
	 (history (if (boolean? history) history (not (eq? id #unspecified))))
	 (body (xml-body body %context))
	 head)
      (if (and (pair? body) (isa? (car body) xml-nphead-element))
	  (begin
	     (set! head (car body))
	     (set! body (filter (lambda (e) (isa? e xml-nptab-element))
			   (cdr body))))
	  (begin
	     (set! head #f)
	     (set! body (filter (lambda (e) (isa? e xml-nptab-element))
			   body))))
      (if (null? body)
	  (error "<NOTEPAD>" "Missing <NPTAB> elements" id)
	  (notepad id class history
	     (map (lambda (a) (xml-primitive-value a %context)) attrs)
	     head body onchange %context))))

;*---------------------------------------------------------------------*/
;*    nptab-get-body ...                                               */
;*---------------------------------------------------------------------*/
(define (nptab-get-body tab)
   (with-access::xml-nptab-element tab (body)
      (if (and (isa? (car body) xml-delay) (null? (cdr body)))
	  (with-access::xml-delay (car body) (thunk)
	     (thunk))
	  body)))

;*---------------------------------------------------------------------*/
;*    make-class-name ...                                              */
;*---------------------------------------------------------------------*/
(define (make-class-name::bstring default::bstring name)
   (if (string? name)
       (string-append default " " name)
       default))

;*---------------------------------------------------------------------*/
;*    notepad ...                                                      */
;*---------------------------------------------------------------------*/
(define (notepad id klass history attrs head tabs onchange ctx)
   
   (define svc
      (call-with-output-string
       (lambda (op)
	  (obj->javascript-attr
	   (procedure->service
	    (lambda (i)
	       (nptab-get-body (list-ref tabs i))))
	   op))))
   
   (define (make-tab-div tab i)
      (with-access::xml-nptab-element tab (attributes (idt id) idtab body klass)
	 (let ((click (format "hop_notepad_select( '~a', '~a', ~a )"
			      id idt (if history "true" "false"))))
	    (set! attributes
		  `(:onclick ,(secure-javascript-attr click)
		      :class ,(string-append klass
				 (if (=fx i 0)
				     " hop-nptab-active"
				     " hop-nptab-inactive"))
		    ,@attributes)))
	 (with-access::xml-element tab (body)
	    (when (and (pair? body)
		       (isa? (car body) xml-delay)
		       (null? (cdr body)))
	       (set! attributes `(:lang "delay" ,@attributes))))
	 (<DIV> :data-hss-tag "hop-notepad-tab-body"
	    :style (if (=fx i 0) "display: block" "display: none")
	    :id idt
	    :data-idtab idtab
	    (cond
	       ((=fx i 0)
		(nptab-get-body tab))
	       ((and (isa? (car body) xml-delay) (null? (cdr body)))
		;; we must not eagerly evaluate the tab...
		"")
	       (else
		body)))))
   
   (let ((bodies (map (lambda (t i) (make-tab-div t i))
		      tabs (iota (length tabs))))
	 (attrs (append-map (lambda (a)
			       (let ((a (xml-primitive-value a ctx)))
				  (list (symbol->keyword (car a)) (cdr a))))
			    attrs)))
      (apply <DIV>
	     :id id
	     :data-hss-tag "hop-notepad"
	     :class (make-class-name "hop-notepad" klass)
	     head
	     (<TABLE> :data-hss-tag "hop-notepad"
		(<TR>
		   (<TD> :id (string-append id "-tabs")
		      :data-hss-tag "hop-notepad-tabs"
		      tabs))
		(<TR>
		   (<TD> :id (string-append id "-body")
		      :data-hss-tag "hop-notepad-body" bodies)))
		(<SCRIPT>
		   (when onchange
		      (format "document.getElementById('~a').onchange = ~a"
			      id (hop->js-callback onchange)))
		   (format "document.getElementById('~a').onkeyup = function(_) { return ~a;}"
			   id svc))
	     attrs)))
   
;*---------------------------------------------------------------------*/
;*    <NPHEAD> ...                                                     */
;*---------------------------------------------------------------------*/
(define-tag <NPHEAD> ((id #unspecified string)
		      (%location #f)
		      (attr)
		      body)
   (instantiate::xml-nphead-element
      (tag 'div)
      (id (xml-make-id id 'NPHEAD))
      (attributes `(:data-hss-tag "hop-nphead" ,@attr))
      (body body)))
   
;*---------------------------------------------------------------------*/
;*    <NPTABHEAD> ...                                                  */
;*---------------------------------------------------------------------*/
(define-tag <NPTABHEAD> ((id #unspecified string)
			 (%location #f)
			 (attr)
			 body)
   (instantiate::xml-nptabhead-element
      (tag 'span)
      (id (xml-make-id id 'NPTABHEAD))
      (attributes `(:data-hss-tag "hop-nptab-head" ,@attr))
      (body body)))
   
;*---------------------------------------------------------------------*/
;*    <NPTAB> ...                                                      */
;*---------------------------------------------------------------------*/
(define-tag <NPTAB> ((id #unspecified string)
		     (%context #f)
		     (class #unspecified string)
		     (selected #f)
		     (onselect #f)
		     (%location #f)
		     (attr)
		     body)
   (let ((head (filter (lambda (b) (isa? b xml-nptabhead-element)) body))
	 (body (filter (lambda (x) (not (isa? x xml-nptabhead-element))) body)))
      (cond
	 ((null? head)
	  (error "<NPTAB>" "Missing <NPTABHEAD> " id))
	 ((null? body)
	  (error "<NPTAB>" "Illegal <NPTABHEAD> " body))
	 (else
	  (let ((cla (make-class-name "hop-nptab " class)))
	     (instantiate::xml-nptab-element
		(tag 'span)
		(id (xml-make-id id 'NPTAB))
		(idtab (xml-make-id #f 'NPTABTAG))
		(attributes `(:data-hss-tag "hop-nptab"
				,@(map (lambda (a)
					  (xml-primitive-value a %context))
				     attr)))
		(klass cla)
		(onselect onselect)
		(head (car head))
		(body body)))))))

;*---------------------------------------------------------------------*/
;*    xml-write ...                                                    */
;*---------------------------------------------------------------------*/
(define-method (xml-write obj::xml-nptab-element p backend)
   (with-access::xml-nptab-element obj (idtab head attributes onselect)
      (display "<span id='" p)
      (display idtab p)
      (display "'" p)
      (xml-write-attributes attributes p backend)
      (display ">" p)
      (when onselect
	 (display "<script>" p)
	 (display "document.getElementById( '" p)
	 (display idtab p)
	 (display "' ).onselect = " p)
	 (display (hop->js-callback onselect) p)
	 (display "</script>" p))
      (xml-write head p backend)
      (display "</span>" p)))

;*---------------------------------------------------------------------*/
;*    xml-compare ::xml-nphead-element ...                             */
;*---------------------------------------------------------------------*/
(define-method (xml-compare a1::xml-nphead-element a2)
   (if (and (isa? a2 xml-markup)
	    (with-access::xml-markup a2 (tag)
	       (eq? tag 'div))
	    (equal? (dom-get-attribute a2 "class") "hop-nphead"))
       (with-access::xml-markup a1 ((body1 body))
	  (with-access::xml-markup a2 ((body2 body))
	     (xml-compare body1 body2)))
       (call-next-method)))

;*---------------------------------------------------------------------*/
;*    xml-compare ::xml-nptabhead-element ...                          */
;*---------------------------------------------------------------------*/
(define-method (xml-compare a1::xml-nptabhead-element a2)
   (if (and (isa? a2 xml-markup)
	    (with-access::xml-markup a2 (tag)
	       (eq? tag 'span))
	    (equal? (dom-get-attribute a2 "data-hss-tag") "hop-nptab-head"))
       (with-access::xml-markup a1 ((body1 body))
	  (with-access::xml-markup a2 ((body2 body))
	     (xml-compare body1 body2)))
       (call-next-method)))

;*---------------------------------------------------------------------*/
;*    xml-compare ::xml-nptab-element ...                              */
;*---------------------------------------------------------------------*/
(define-method (xml-compare a1::xml-nptab-element a2)
   (if (and (isa? a2 xml-markup)
	    (with-access::xml-markup a2 (tag)
	       (eq? tag 'span))
	    (equal? (dom-get-attribute a2 "data-hss-tag") "hop-nptab")
	    (let ((head (dom-first-child a2))
		  (body (cadr (dom-child-nodes a2))))
	       (xml-compare (cadr (dom-child-nodes a1)) head)))
       (call-next-method)))
