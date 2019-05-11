;;;; tcpserver.scm
;
; Copyright (c) 2000-2008, Felix L. Winkelmann
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following
; conditions are met:
;
;   Redistributions of source code must retain the above copyright notice, this list of conditions and the following
;     disclaimer. 
;   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
;     disclaimer in the documentation and/or other materials provided with the distribution. 
;   Neither the name of the author nor the names of its contributors may be used to endorse or promote
;     products derived from this software without specific prior written permission. 
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
; AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.


(declare (fixnum))


(module tcp-server (tcp-server-prepare-hard-close-procedure
		    tcp-server-accept-connection-procedure
		    tcp-server-get-addresses-procedure
		    make-tcp-server)

  (import scheme chicken)
  (use extras tcp srfi-18)

;;; Constants:

(define-constant default-request-count-limit 10000)

;;; Parameters:

(define tcp-server-prepare-hard-close-procedure
  (make-parameter tcp-abandon-port))
(define tcp-server-accept-connection-procedure
  (make-parameter tcp-accept))
(define tcp-server-get-addresses-procedure
  (make-parameter tcp-addresses))

;;; Main loop:

(define (make-tcp-server listener thunk . maxc)
  (let ([max-requests (optional maxc default-request-count-limit)]
	[current-number-of-threads 0]
	[verbose #f] )
    (define (dribble fstr . args)
      (when verbose
	(fprintf (current-error-port) "[~A] ~?~%~!" (if (string? verbose) verbose "tcp-server") fstr args) ) )
    (define (close-connection in out)
      (dribble "closing connection...")
      (close-output-port out)
      (close-input-port in) )
    (define (hard-close in out)
      ((tcp-server-prepare-hard-close-procedure) in)
      ((tcp-server-prepare-hard-close-procedure) out)
      (close-input-port in)
      (close-output-port out) )
    (define (thread-fork thunk)
      (set! current-number-of-threads (add1 current-number-of-threads))
      (thread-start! (make-thread thunk))
      (set! current-number-of-threads (sub1 current-number-of-threads)) )
    (define (dispatch-request in out)
      (handle-exceptions ex
	  (begin
	    (hard-close in out)
	    (signal ex) )
	(current-input-port in)
	(current-output-port out)
	(thunk)
	(close-connection in out) ) )
    (lambda dbg
      (set! verbose (optional dbg #f))
      (dribble "waiting for requests...")
      (let ([count 0])
	(define (serve)
	  (let-values ([(in out)
			((tcp-server-accept-connection-procedure) listener)])
	    (thread-fork
	     (lambda ()
	       (let ([id (thread-name (current-thread))])
		 (when verbose
		   (let-values ([(_ you)
				 ((tcp-server-get-addresses-procedure) in)])
		     (dribble "request ~A from ~A; ~A (of ~A) started..." count you id current-number-of-threads) ) )
		 (let ([k (dispatch-request in out)])
		   (set! count (add1 count))
		   (dribble "~A finished." id) ) ) ) ) ) )
	(let loop ()
	  (if (< current-number-of-threads max-requests)
	      (serve)
	      (thread-yield!) )
	  (loop) ) ) ) ) )

)
