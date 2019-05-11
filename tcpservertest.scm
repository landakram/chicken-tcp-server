(use tcp-server extras posix)

((make-tcp-server 
  (tcp-listen 6502) 
  (lambda () 
    (printf "~A: ~A~%" (read-line) (seconds->string (current-seconds))) ) )
 #t)
