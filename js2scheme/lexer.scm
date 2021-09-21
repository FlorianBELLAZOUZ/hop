;*=====================================================================*/
;*    serrano/prgm/project/hop/hop/js2scheme/lexer.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sun Sep  8 07:33:09 2013                          */
;*    Last change :  Tue Sep 21 07:04:06 2021 (serrano)                */
;*    Copyright   :  2013-21 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    JavaScript lexer                                                 */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __js2scheme_lexer
   
   (include "token.sch")

   (import __js2scheme_ast
	   __js2scheme_utils)
   
   (export (j2s-lexer)
	   (j2s-template-lexer)
	   (j2s-regex-lexer)
	   (j2s-reserved-id? ::symbol)
	   (j2s-strict-reserved-id? ::symbol)
	   (j2s-escape-js-string ::bstring ::input-port)))

;*---------------------------------------------------------------------*/
;*    reserved identifiers                                             */
;*---------------------------------------------------------------------*/
(define (j2s-reserved-id? sym)
   (or (getprop sym 'reserved)
       (and *JS-care-future-reserved* (getprop sym 'future-reserved))))

;*---------------------------------------------------------------------*/
;*    j2s-strict-reserved-id? ...                                      */
;*---------------------------------------------------------------------*/
(define (j2s-strict-reserved-id? sym)
   (or (getprop sym 'future-strict-reserved)
       (getprop sym 'future-reserved)))
       
(define *JS-care-future-reserved* #t)

;; https://www.ecma-international.org/ecma-262/10.0/index.html#sec-keywords
(define *keyword-list*
   '("await"
     "break"
     "case"
     "catch"
     "const"
     "continue"
     "debugger"
     "default"
     "delete"
     "do"
     "else"
     "false"
     "finally"
     "for"
     "function"
     "if"
     "in"
     "instanceof"
     "let"
     "new"
     "null"
     "return"
     "switch"
     "this"
     "throw"
     "true"
     "try"
     "typeof"
     "var"
     "void"
     "while"
     "with"
     "yield"
     ;; es2015 classes
     "class"
     "extends"
     "super"))

(define *future-reserved-list*
   '("enum"
     "export"
     "import"))

(define *hopscript-reserved-list*
   '("record"))

(define *future-strict-reserved-list*
   '("implements"
     "interface"
     "package"
     "private"
     "protected"
     "public"))

(for-each (lambda (word)
	     (putprop! (string->symbol word) 'reserved #t))
	  *keyword-list*)

(for-each (lambda (word)
	     (putprop! (string->symbol word) 'future-reserved #t))
	  *future-reserved-list*)

(for-each (lambda (word)
	     (putprop! (string->symbol word) 'hopscript-reserved #t))
	  *hopscript-reserved-list*)

(for-each (lambda (word)
	     (putprop! (string->symbol word) 'future-strict-reserved #t))
	  *future-strict-reserved-list*)

;*---------------------------------------------------------------------*/
;*    token-string ...                                                 */
;*---------------------------------------------------------------------*/
(define-macro (token-string value offset . tag)
   `(let ((s ,value))
       (if (utf8-string? s)
	   (make-token ,(if (pair? tag) (car tag) ''STRING)
	      s (the-coord (the-port) ,offset))
	   (make-token 'BAD (cons "wrong UTF8 string" s) (the-coord (the-port) ,offset)))))

;*---------------------------------------------------------------------*/
;*    j2s-grammar ...                                                  */
;*---------------------------------------------------------------------*/
(define j2s-grammar
   (regular-grammar
	 ;; TODO: are a010 and a013 really correct?
	 ((blank_u (or "\xc2\xa0"))
	  (blank (or (in #\Space #\Tab #a010 #a011 #a012 #a013 #\Newline)
		     blank_u))
	  (blank_no_lt (or (in #\Space #\Tab #a011 #a012) blank_u))
	  (bom_utf8 "\xef\xbb\xbf")
	  (bom_utf16_le "\xff\xfe")
	  (bom_utf16_be "\xfe\xff")
	  (lt (in #a013 #\Newline))
	  (odigit (in "07"))
	  (nonzero_digit (in ("19")))
	  (e2 (or (: "\xe2" (out "\x80")) (: "\xe2\x80" (out "\xa8\xa9"))))
	  (id_part_sans (or (in #a127 #a225) (in #a227 #a255) e2))
	  (unicode_char (: (in "\xd0\xd1") (or all #\Newline)))
	  (alpha+ (or alpha unicode_char))
	  (alnum+ (or alnum unicode_char))
	  (id_start (or alpha+ #\$ #\_ id_part_sans))
	  (id_part (or alnum+ #\$ #\_ id_part_sans))
	  (id_start_u (or unicode alpha+ #\$ #\_ id_part_sans))
	  (id_part_u (or unicode alnum+ #\$ #\_ id_part_sans))
	  (letter (in ("azAZ") (#a128 #a255)))
	  (kspecial (in "!@$%^&*></-_+\\=?"))
	  (special (or kspecial #\:))
	  (tagid (: (* digit)
		    (or letter digit #\_)
		    (* (or letter digit #\_ #\. #\:))))
	  (unicode (: #\\ #\u
		      (or (: (in ("0139afAF")) (= 3 (in ("09afAF"))))
			  (: "2" (in ("19afAF")) (= 2 (in ("09afAF"))))
			  (: "20" (in ("0139afAF")) (in ("09afAF")))
			  (: "202" (in ("07afAF"))))))
	  (ls "\xe2\x80\xa8")
	  (ps "\xe2\x80\xa9")
	  (line_cont (: #\\ (or "\n" "\r\n" ls ps)))
	  (string_char (or (out #a226 #\" #\' #\\ #\Return #\Newline) e2))
	  (string_char_quote (or #\' string_char))
	  (string_char_dquote (or #\" string_char))
	  lang conf)

      (define (octalllong n::llong)
       (let loop ((power #l1)
		  (n n)
		  (res #l0))
	  (if (=llong n #l0)
	      res
	      (loop (*llong power #l8)
		 (/llong n #l8)
		 (+llong (*llong (modulollong n #l8) power) res)))))
      
      ((+ blank_no_lt)
       (ignore))

      (bom_utf8
       (ignore))

      ((or bom_utf16_le bom_utf16_be)
       (token 'ERROR (string-for-read (the-string)) 1))

      ((: "#!/" (+ all))
       (ignore))
      
      ((or ls ps)
       (token 'NEWLINE 'ls 1))
      
      ((: (* blank_no_lt) lt (* blank))
       (token 'NEWLINE #\newline 1))

      ;; line comment
      ((: "//" (* (or (out "\n\xe2\r")
		      (: "\xe2" (out "\x80"))
		      (: "\xe2\x80" (out "\xa8\xa9")))))
       (if (and (>fx (the-length) 20)
		(=fx (the-byte-ref 2) (char->integer #\#)))
	   ;; source-map parsing
	   (let* ((s (the-substring 3 (the-length)))
		  (i (string-skip s " \t" 0)))
	      (if (and i (substring-at? s "sourceMappingURL=" i))
		  (token 'SOURCEMAP (substring s (+fx i 17)) (the-length))
		  (ignore)))
	   (ignore)))

      ;; type comments
      ((: "/*:" (* #\Space) (+ letter) (* #\Space) "*/")
       (let ((typ (string->symbol (the-substring 3 -2))))
	  (if (config-get conf :type-annotations #f)
	      (token 'TYPE typ (-fx (the-length) 5))
	      (ignore))))

      ;; multi-line comment on one line
      ((: "/*" (* (or (out #\*) (: (+ #\*) (out #\/ #\*)))) (+ #\*) "/")
       (ignore))

      ;; multi-line comment with LineTerminators (several lines)
      ((: "/*"
	  (* (or lt
		 (out #\*)
		 (: (+ #\*) (out #\/ #\*))))
	  (+ #\*) "/")
       (token 'NEWLINE #\newline 1))

      ;; builtin decorator
      ((: (? (: "//" (or #\space #\tab))) "@record" (+ blank) "class")
       (token 'record 'record (the-length)))

      ;; numbers
      (#\0
       (token 'NUMBER 0 (the-length)))
      ((+ #\0)
       (token 'OCTALNUMBER 0 (the-length)))
      ((: nonzero_digit (* digit))
       ;; integer constant
       (let* ((len (the-length))
	      (val (cond
		      ((<=fx len 8) (the-fixnum))
		      ((>=fx len 21) (the-flonum))
		      ((>=fx len 18) (the-flonum))
		      (else (js-string->number (the-string))))))
	  (token 'NUMBER val len)))
      ((: (+ #\0) (in ("17")) (* (in ("07"))))
       ;; integer constant
       (let* ((len (the-length))
	      (val (if (>=fx len 18)
		       (let ((o (octalllong (string->llong (the-string)))))
			  (if (>llong o (bit-lshllong #l1 29))
			      (llong->bignum o)
			      (llong->fixnum o)))
		       (js-string->number (the-string) 8))))
	  (token 'OCTALNUMBER val len)))
      ((: (+ digit) (: (in #\e #\E) #\- (+ digit)))
       ;; floating-point constant
       (token 'NUMBER (js-string->number (the-string)) (the-length)))
      ((: (or (: (+ digit) #\. (* digit)) (: #\. (+ digit)))
	  (? (: (in #\e #\E) (? (in #\- #\+)) (+ digit))))
       (token 'NUMBER (js-string->number (the-string)) (the-length)))
      ((: (+ digit) (: (in #\e #\E) (? #\+) (+ digit)))
       ;; a bigint
       (let* ((s (the-string))
	      (i (string-index s "eE"))
	      (base (string->bignum (substring s 0 i)))
	      (rest (string->bignum
		       (if (char=? (string-ref s (+fx i 1)) #\+)
			   (substring s (+fx i 2))
			   (substring s (+fx i 1)))))
	      (flo (bignum->flonum (*bx base (exptbx #z10 rest)))))
	  (token 'NUMBER
	     (if (and (integer? flo)
		      (<fl flo (fixnum->flonum (-fx (bit-lsh 1 29) 1)))
		      (>=fl flo (negfl (fixnum->flonum (bit-lsh 1 29)))))
		 ;; could be more precise
		 (flonum->fixnum flo)
		 flo)
	     (the-length))))
      ((: (uncase "0x") (+ xdigit))
       (token 'NUMBER (js-string->number (the-substring 2 (the-length)) 16)
	  (the-length)))
      ((: (uncase "0o") (+ odigit))
       (token 'NUMBER (js-string->number (the-substring 2 (the-length)) 8)
	  (the-length)))

      ;; bigint
      ((: (? #\-) (+ digit) #\n)
       (token 'BIGINT
	  (string->bignum (the-substring 0 (-fx (the-length) 1)) 10)
	  (the-length)))
      ((: "0x" (+ xdigit) #\n)
       (token 'BIGINT
	  (string->bignum (the-substring 2 (-fx (the-length) 1)) 16)
	  (the-length)))
      
      (#\{ (token 'LBRACE #\{ 1))
      (#\} (token 'RBRACE #\} 1))
      (#\( (token 'LPAREN #\( 1))
      (#\) (token 'RPAREN #\) 1))
      (#\[ (token 'LBRACKET #\[ 1))
      (#\] (token 'RBRACKET #\] 1))
      (#\# (token 'SHARP #\# 1))
      (#\. (token 'DOT #\. 1))
      (#\; (token 'SEMICOLON #\; 1))
      (#\, (token 'COMMA #\, 1))
      (#\| (token 'BIT_OR #\| 1))
      ("||" (token 'OR "||" 2))
      ("|=" (token 'BIT_OR= "|=" 2))
      ((or #\< #\> "<=" ">=" "==" "!=" "===" "!==" #\+ #\- #\* #\% "**" "++" "--"
	   "<<" ">>" ">>>" #\& #\^ #\! #\~ "&&" #\: #\= "+=" "-="  
	   "*=" "%=" "<<=" ">>=" ">>>=" "&=" "^=" "/=" "**=" #\/ #\? "??" "?.")
       (token (the-symbol) (the-string) (the-length)))
      ("=>" (token '=> "=>" 2))
      ("..." (token 'DOTS '|...| 3))

      ;; strings
      ((: #\" (* string_char_quote) #\")
       (token-string (the-substring 1 (-fx (the-length) 1)) (the-length)))
      ((: #\' (* string_char_dquote) #\')
       (token-string (the-substring 1 (-fx (the-length) 1)) (the-length)))
      ((: #\" (* (or string_char_quote (: #\\ all) line_cont)) #\")
       (j2s-escape-js-string (the-substring 1 (-fx (the-length) 1)) (the-port)))
      ((: #\' (* (or string_char_dquote (: #\\ all) line_cont)) #\')
       (j2s-escape-js-string (the-substring 1 (-fx (the-length) 1)) (the-port)))

      ;; template strings
      (#\`
       (read/rp j2s-template-grammar (the-port)))
      
      ;; hopscript pragma
      ((: "#:"
	  (: (* digit)
	     (or letter special)
	     (* (or letter special digit (in "'`")))))
       (let* ((len (the-length))
	      (sym (string->symbol (the-substring 2 len))))
	  (token (if (eq? sym 'pragma) 'PRAGMA 'HOP) sym len)))

      ;; hopscript escapes
      ("~{"
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (token 'TILDE (the-string) (the-length))))
      ("${"
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (token 'DOLLAR (the-string) (the-length))))
      
      ;; identifiers and keywords
      ((: id_start (* id_part))
       (let ((symbol (the-symbol)))
	  (cond
	     ((getprop symbol 'reserved)
	      (token symbol symbol (the-length)))
	     ((and *JS-care-future-reserved* (getprop symbol 'future-reserved))
	      (token 'RESERVED symbol (the-length)))
	     ((and (getprop symbol 'hopscript-reserved)
		   (string=? lang "hopscript"))
	      (token symbol symbol (the-length)))
	     (else
	      (token 'ID symbol (the-length))))))
      ((: #\# id_start (* id_part))
       (let ((symbol (the-symbol)))
	  (token 'SHARPID symbol (the-length))))

      ((: id_start_u (* id_part_u))
       (let ((str (the-string)))
	  (cond
	     ((unicode-whitespace? str)
	      (token 'BADTOKEN str (string-length str)))
	     ((no-line-terminator "continue\\u" str)
	      (unread-string! (substring str 0 8) (the-port))
	      (token 'continue 'continue 9))
	     ((no-line-terminator "break\\u" str)
	      (unread-string! (substring str 0 5) (the-port))
	      (token 'break 'break 5))
	     ((no-line-terminator "throw\\u" str)
	      (unread-string! (substring str 0 5) (the-port))
	      (token 'throw 'throw 5))
	     ((no-line-terminator "return\\u" str)
	      (unread-string! (substring str 0 7) (the-port))
	      (token 'return 'return 7))
	     (else
	      (let ((estr (j2s-escape-js-string str (the-port))))
		 (if (memq (car estr) '(ESTRING OSTRING))
		     (let ((symbol (string->symbol (cdr estr))))
			(cond
			   ((getprop symbol 'reserved)
			    (token symbol symbol (the-length)))
			   ((and *JS-care-future-reserved*
				 (getprop symbol 'future-reserved))
			    (token symbol symbol (the-length)))
			   ((and (getprop symbol 'hopscript-reserved)
				 (string=? lang "hopscript"))
			    (token symbol symbol (the-length)))
			   (else
			    (token 'ID symbol (the-length)))))
		     estr))))))

      ((: "<!--"
	  (* (or (out "-") (: "-" (out "-")) (: "--" (out ">"))))
	  (+ "-") "->")
       ;; html comments
       (token 'HTMLCOMMENT (the-substring 4 -3) (the-length)))
      ;; tags (hopscript extension)
      ((: "<" tagid ">")
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (token 'OTAG (the-symbol) (the-length))))
      
      ;; closing tags (hopscript extension)
      ((: "</" tagid ">")
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (token 'CTAG
	      (symbol-append '< (string->symbol (the-substring 2 -1)) '>)
	      (the-length))))

      ;; HTML
      ((: "<" tagid (+ (in " \t\n")) (or tagid "${" "/>" ">"))
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (let* ((str (the-string))
		  (i (string-index str " \t\n")))
	      (rgc-buffer-insert-substring! (the-port) str
		 (+fx i 1) (string-length str))
	      (token 'OHTML (string->symbol (substring str 0 i)) i))))
      ((: "<" tagid "/>")
       (if (eq? lang 'javascript)
	   (token 'ERROR (the-string) (the-length))
	   (token 'HTML (symbol-append (the-subsymbol 0 -2) '>) (the-length))))
      ((: "<!" tagid (+ (out #\>)) ">")
       (token 'DOCTYPE (the-string) (the-length)))
      
      ;; error
      (else
       (let ((c (the-failure)))
	  (cond
	     ((eof-object? c)
	      (token 'EOF c 0))
	     ((and (char? c) (char=? c #a000))
	      (token 'PRAGMA #unspecified 1))
	     (else
	      (token 'ERROR c 1)))))))

;*---------------------------------------------------------------------*/
;*    j2s-template-grammar ...                                         */
;*---------------------------------------------------------------------*/
(define j2s-template-grammar
   (regular-grammar ()
      ((or (: (* (out "`{")) "`")
	   (: (* (out "`$")) "`")
	   (: (* (or (out "`$") (: #\$ (out "`${")))) "`")
	   (: (* (or (out "`$") (: #\$ (out "`${")))) "$`"))
       ;; template string no escape
       (let ((str (the-substring 0 -1)))
	  (token-string (pregexp-replace* "\r\n?" str "\n")
	     (the-length) 'TSTRING)))
      ((or (: (* (or (out "`{") "\\`")) "`")
	   (: (* (or (out "`$") "\\`")) "`")
	   (: (* (or (out "`$") "\\`" (: #\$ (out "`${")))) "`")
	   (: (* (or (out "`$") "\\`" (: #\$ (out "`${")))) "$`"))
       ;; template string no escape
       (let ((str (the-substring 0 -1)))
	  (token-string
	     (pregexp-replace* "\r\n?"
		(pregexp-replace* "\\\\" str "")
		"\n")
	     (the-length) 'TSTRING)))
      
      ((: (* (or (out "`$") (: #\$ (out "${")))) "${")
       ;; template string with escape sequence
       (rgc-buffer-unget-char (the-port) (char->integer #\{))
       (token 'TEMPLATE (pregexp-replace* "\r\n?" (the-substring 0 -1) "\n")
	  (the-length)))
      ((: (* (or (out "`$") "\\`" (: #\$ (out "${")))) "${")
       ;; template string with escape sequence
       (rgc-buffer-unget-char (the-port) (char->integer #\{))
       (token 'TEMPLATE
	  (pregexp-replace* "\r\n?"
	     (pregexp-replace* "\\\\" (the-substring 0 -1) "")
	     "\n")
	  (the-length)))
      
      ((: (* (or (out "`$") (: #\$ (out "${")))) "$$")
       ;; template string with escape, with double $$
       (let ((str (the-substring 0 -1)))
	  (rgc-buffer-unget-char (the-port) (char->integer #\$))
	  (token-string (pregexp-replace "[$][$]" (pregexp-replace* "\r\n?" str "\n") "$")
	     (the-length) 'TEMPLATE)))
      ((: (* (or (out "`$") "\\`" (: #\$ (out "${")))) "$$")
       ;; template string with escape, with double $$
       (let ((str (the-substring 0 -1)))
	  (rgc-buffer-unget-char (the-port) (char->integer #\$))
	  (token-string
	     (pregexp-replace "[$][$]"
		(pregexp-replace* "\r\n?"
		   (pregexp-replace* "\\\\" str "")
		   "\n")
		"$")
	     (the-length) 'TEMPLATE)))
      
      ((: (* (or (out "`$") (: #\$ (out "${")))) "$${")
       ;; template string with escape, with double $$
       (let ((str (the-substring 0 -1)))
	  (rgc-buffer-unget-char (the-port) (char->integer #\{))
	  (token-string (pregexp-replace "[$][$]" (pregexp-replace* "\r\n?" str "\n") "$")
	     (the-length) 'TEMPLATE)))
      ((: (* (or (out "`$") "\\`" (: #\$ (out "${")))) "$${")
       ;; template string with escape, with double $$
       (let ((str (the-substring 0 -1)))
	  (rgc-buffer-unget-char (the-port) (char->integer #\{))
	  (token-string
	     (pregexp-replace "[$][$]"
		(pregexp-replace* "\r\n?"
		   (pregexp-replace* "\\\\" str "")
		   "\n")
		"$")
	     (the-length) 'TEMPLATE)))
      
      (else
       (let ((c (the-failure)))
	  (cond
	     ((eof-object? c)
	      (token 'EOF c 0))
	     ((and (char? c) (char=? c #a000))
	      (token 'PRAGMA #unspecified 1))
	     (else
	      (token 'ERROR c 1)))))))
	 
;*---------------------------------------------------------------------*/
;*    no-line-terminator ...                                           */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-7.3          */
;*---------------------------------------------------------------------*/
(define (no-line-terminator prefix str)
   (and (string-prefix? prefix str)
	(let ((offset (string-length prefix)))
	   (or (substring-at? str "000A" offset)
	       (substring-at? str "000a" offset)
	       (substring-at? str "000D" offset)
	       (substring-at? str "000d" offset)
	       (substring-at? str "2028" offset)
	       (substring-at? str "2029" offset)))))

;*---------------------------------------------------------------------*/
;*    unicode-whitespace? ...                                          */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-7.2          */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-7.6          */
;*---------------------------------------------------------------------*/
(define (unicode-whitespace? str)
   (let ((len2 (-fx (string-length str) 2)))
      (let loop ((r 0))
	 (let ((i (string-index str "\\u00" r)))
	    (when (and i (<fx i len2))
	       (if (or (substring-at? str "\\u0009" i)
		       (substring-at? str "\\u000b" i)
		       (substring-at? str "\\u000B" i)
		       (substring-at? str "\\u000c" i)
		       (substring-at? str "\\u000C" i)
		       (substring-at? str "\\u0020" i)
		       (substring-at? str "\\u00a0" i)
		       (substring-at? str "\\u00A0" i))
		   #t
		   (loop (+fx i 6))))))))

;*---------------------------------------------------------------------*/
;*    j2s-escape-js-string ...                                         */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-7.8.4        */
;*---------------------------------------------------------------------*/
(define (j2s-escape-js-string str input-port)
   
   (define (err)
      (make-token 'ERROR str
	 (the-coord input-port (+fx (string-length str) 1))))
   
   (define (char-alpha c)
      (cond
	 ((char>=? c #\a)
	  (when (char<=? c #\f)
	     (+fx 10 (-fx (char->integer c) (char->integer #\a)))))
	 ((char>=? c #\A)
	  (when (char<=? c #\F)
	     (+fx 10 (-fx  (char->integer c) (char->integer #\A)))))
	 ((char>=? c #\0)
	  (when (char<=? c #\9)
	     (-fx (char->integer c) (char->integer #\0))))
	 (else
	  #f)))
   
   (define (hex2 str j)
      (let ((n1 (char-alpha (string-ref str j))))
	 (when n1
	    (let ((n2 (char-alpha (string-ref str (+fx j 1)))))
	       (when n2
		  (+fx (*fx n1 16) n2))))))
   
   (define (hex4 str j)
      (let ((n1 (hex2 str j)))
	 (when n1
	    (let ((n2 (hex2 str (+fx j 2))))
	       (when n2
		  (+fx (*fx n1 256) n2))))))
   
   (define (hex6 str j len)
      (let ((n1 (char-alpha (string-ref str j))))
	 (if n1
	    (let loop ((n n1)
		       (j (+fx j 1)))
	       (if (=fx j len)
		   (values #f 0)
		   (let ((c (string-ref str j)))
		      (cond
			 ((char=? c #\})
			  (values n j))
			 ((char-alpha c)
			  =>
			  (lambda (m)
			     (loop (+fx (bit-lsh n 4) m) (+fx j 1))))
			 (else
			  (values #f 0))))))
	    (values #f 0))))
   
   (define (integer->utf8 n)
      (let ((u (make-ucs2-string 1 (integer->ucs2 n))))
	 (ucs2-string->utf8-string u)))

   (define (integer32->utf8 n)
      (if (>=fx n #xFFFF)
	  (let ((buf (make-string 4)))
	     (string-set! buf 0
		(integer->char (bit-or #xf0 (bit-rsh n 18))))
	     (string-set! buf 1
		(integer->char (bit-or #x80 (bit-and #x3f (bit-rsh n 12)))))
	     (string-set! buf 2
		(integer->char (bit-or #x80 (bit-and #x3f (bit-rsh n 6)))))
	     (string-set! buf 3
		(integer->char (bit-or #x80 (bit-and #x3f n))))
	     buf)
	  (integer->utf8 n)))

   (define (integer2->utf8 n1 n2)
      (let ((u (make-ucs2-string 2 (integer->ucs2 n1))))
	 (ucs2-string-set! u 1 (integer->ucs2 n2))
	 (ucs2-string->utf8-string u)))
   
   (define (octal? c)
      (and (char>=? c #\0) (char<=? c #\7)))

   (define (octal-char c1)
      (-fx (char->integer c1) (char->integer #\0)))
   
   (define (octal-val str index len)
      (let loop ((i index)
		 (val 0))
	 (if (or (=fx i len) (not (octal? (string-ref str i))))
	     (values val (-fx i index))
	     (loop (+fx i 1)
		(+fx (*fx val 8) (octal-char (string-ref str i)))))))

   (let* ((len (string-length str))
	  (res (make-string len)))
      (let loop ((i 0)
		 (w 0)
		 (octal #f))
	 (let ((j (string-index str #\\ i)))
	    (cond
	       ((not j)
		(blit-string! str i res w (-fx len i))
		(string-shrink! res (+fx w (-fx len i)))
		(make-token (if octal 'OSTRING 'ESTRING) res
		   (the-coord input-port (+fx len 1))))
	       ((=fx j (-fx len 1))
		(err))
	       (else
		(when (>fx j i)
		   (blit-string! str i res w (-fx j i))
		   (set! w (+fx w (-fx j i))))
		(let ((c (string-ref str (+fx j 1))))
		   (case c
		      ((#\' #\" #\\)
		       (string-set! res w c)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\b)
		       (string-set! res w #a008)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\f)
		       (string-set! res w #a012)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\n)
		       (string-set! res w #a010)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\r)
		       (string-set! res w #a013)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\t)
		       (string-set! res w #a009)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\v)
		       (string-set! res w #a011)
		       (loop (+fx j 2) (+fx w 1) octal))
		      ((#\x)
		       (if (>=fx j (-fx len 3))
			   (err)
			   (let ((n (hex2 str (+fx j 2))))
			      (if n
				  (let* ((s (integer->utf8 n))
					 (l (string-length s)))
				     (blit-string! s 0 res w l)
				     (loop (+fx j 4) (+fx w l) octal))
				  (err)))))
		      ((#\u)
		       (cond
			  ((and (<fx j (-fx len 4)) (char=? (string-ref str (+fx j 2)) #\{))
			   (multiple-value-bind (n nj)
			      (hex6 str (+fx j 3) len)
			      (cond
				 ((not n)
				  (err))
				 (else
				  (let* ((s (integer32->utf8 n))
					 (l (string-length s)))
				     (blit-string! s 0 res w l)
				     (loop (+fx nj 1) (+fx w l) octal))))))
			  ((>=fx j (-fx len 5))
			   (err))
			  (else
			   (let ((n (hex4 str (+fx j 2))))
			      (cond
				 ((not n)
				  (err))
				 ((and (>=fx n #xd800) (<=fx n #xdfff)
				       (<fx j (-fx len 11))
				       (char=? (string-ref str (+fx j 6)) #\\)
				       (char=? (string-ref str (+fx j 7)) #\u))
				  (let ((n2 (hex4 str (+fx j 8))))
				     (if (=fx (bit-and n2 #xdc00) #xdc00)
					 ;; utf16-be character
					 ;; http://en.wikipedia.org/wiki/UTF-16
					 ;; http://fr.wikipedia.org/wiki/UTF-16
					 (let* ((s (integer2->utf8 n n2))
						(l (string-length s)))
					    (blit-string! s 0 res w l)
					    (loop (+fx j 12) (+fx w l) octal))
					 ;; consider a single ucs2 char
					 (let* ((s (integer->utf8 n))
						(l (string-length s)))
					    (blit-string! s 0 res w l)
					    (loop (+fx j 6) (+fx w l) octal)))))
				 (else
				  (let* ((s (integer->utf8 n))
					 (l (string-length s)))
				     (blit-string! s 0 res w l)
				     (loop (+fx j 6) (+fx w l) octal))))))))
		      ((#\newline)
		       (loop (+fx j 2) w octal))
		      ((#\return)
		       (if (and (<fx (+fx j 2) len)
				(char=? (string-ref str (+fx j 2)) #\Newline))
			   (loop (+fx j 3) w octal)
			   (loop (+fx j 1) w octal)))
		      ((#a226)
		       (if (and (<fx (+fx j 3) len)
				(char=? (string-ref str (+fx j 2)) #a128)
				(or (char=? (string-ref str (+fx j 3)) #a168)
				    (char=? (string-ref str (+fx j 3)) #a169)))
			   (loop (+fx j 4) w octal)
			   (loop (+fx j 1) w octal)))
		      ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7)
		       (multiple-value-bind (n lo)
			  (octal-val str (+fx j 1) (minfx len (+fx j 4)))
			  (let* ((s (integer->utf8 n))
				 (l (string-length s)))
			     (blit-string! s 0 res w l)
			     (loop (+fx j (+fx lo 1)) (+fx w l)
				(or (>fx n 0) (>fx lo 1))))))
		      (else
		       (loop (+fx j 1) w octal))))))))))

;*---------------------------------------------------------------------*/
;*    j2s-regex-grammar ...                                            */
;*    -------------------------------------------------------------    */
;*    http://www.ecma-international.org/ecma-262/5.1/#sec-7.8.5        */
;*---------------------------------------------------------------------*/
(define j2s-regex-grammar 
   (regular-grammar ((ls "\xe2\x80\xa8")
		     (ps "\xe2\x80\xa9")
		     (lt (in #a013 #\Newline "\xe2"))
		     (e2 (or (: "\xe2" (out "\x80"))
			     (: "\xe2\x80" (out "\xa8\xa9"))))
		     (nonsep (or (out lt) e2))
		     (escape (: #\\ nonsep))
		     (range (: #\[ (* (or (out lt #\]) e2)) #\]))
		     (start (+ (or (out #\/ #\* #\\ #\[ lt) escape range e2)))
		     (regexp (: start (* (or (out #\/ #\\ #\[ lt) e2 escape range)))))
      ((: regexp "/" (+ (in "igm")))
       (let* ((s (the-string))
	      (l (the-length))
	      (i (string-index-right s "/"))
	      (rx (substring s 0 i)))
	  (token 'RegExp (cons (substring s 0 i) (substring s (+fx i 1) l)) 0)))
      ((: regexp "/")
       (token 'RegExp (cons (the-substring 0 -1) "") 0))
      (else
       (let ((c (the-failure)))
	  (if (eof-object? c)
	      (token 'EOF c 0)
	      (token 'ERROR c 0))))))

;*---------------------------------------------------------------------*/
;*    j2s-lexer ...                                                    */
;*---------------------------------------------------------------------*/
(define (j2s-lexer)
   j2s-grammar)

;*---------------------------------------------------------------------*/
;*    j2s-template-lexer ...                                           */
;*---------------------------------------------------------------------*/
(define (j2s-template-lexer)
   j2s-template-grammar)

;*---------------------------------------------------------------------*/
;*    j2s-regex-lexer ...                                              */
;*---------------------------------------------------------------------*/
(define (j2s-regex-lexer)
   j2s-regex-grammar)

;*---------------------------------------------------------------------*/
;*    js-string->number ...                                            */
;*---------------------------------------------------------------------*/
(define (js-string->number str #!optional (radix 10))
   (let ((n (string->number str radix)))
      (if (bignum? n)
	  (bignum->flonum n)
	  n)))
