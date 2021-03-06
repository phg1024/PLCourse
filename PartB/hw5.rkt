;; Programming Languages, Homework 5

#lang racket
(provide (all-defined-out)) ;; so we can put tests in a second file

;; definition of structures for MUPL programs - Do NOT change
(struct var  (string) #:transparent)  ;; a variable, e.g., (var "foo")
(struct int  (num)    #:transparent)  ;; a constant number, e.g., (int 17)
(struct add  (e1 e2)  #:transparent)  ;; add two expressions
(struct ifgreater (e1 e2 e3 e4)    #:transparent) ;; if e1 > e2 then e3 else e4
(struct fun  (nameopt formal body) #:transparent) ;; a recursive(?) 1-argument function
(struct call (funexp actual)       #:transparent) ;; function call
(struct mlet (var e body) #:transparent) ;; a local binding (let var = e in body)
(struct apair (e1 e2)     #:transparent) ;; make a new pair
(struct fst  (e)    #:transparent) ;; get first part of a pair
(struct snd  (e)    #:transparent) ;; get second part of a pair
(struct aunit ()    #:transparent) ;; unit value -- good for ending a list
(struct isaunit (e) #:transparent) ;; evaluate to 1 if e is unit else 0

;; a closure is not in "source" programs but /is/ a MUPL value; it is what functions evaluate to
(struct closure (env fun) #:transparent)

;; Problem 1

(define (racketlist->mupllist lst)
  (if (null? lst) (aunit)
      (apair (car lst) (racketlist->mupllist (cdr lst)))))

;; Problem 2
(define (mupllist->racketlist lst)
  (if (apair? lst) (cons (apair-e1 lst) (mupllist->racketlist (apair-e2 lst)))
      null))

;; lookup a variable in an environment
;; Do NOT change this function
(define (envlookup env str)
  (cond [(null? env) (error "unbound variable during evaluation" str)]
        [(equal? (car (car env)) str) (cdr (car env))]
        [#t (envlookup (cdr env) str)]))

;; Do NOT change the two cases given to you.
;; DO add more cases for other kinds of MUPL expressions.
;; We will test eval-under-env by calling it directly even though
;; "in real life" it would be a helper function of eval-exp.
(define (eval-under-env e env)
  (begin (print "eval") (println e) (println env)
  (cond [(var? e)
         (envlookup env (var-string e))]
        [(add? e)
         (let ([v1 (eval-under-env (add-e1 e) env)]
               [v2 (eval-under-env (add-e2 e) env)])
           (if (and (int? v1)
                    (int? v2))
               (int (+ (int-num v1)
                       (int-num v2)))
               (error "MUPL addition applied to non-number")))]
        [(int? e) e]
        [(ifgreater? e)
         (let ([v1 (eval-under-env (ifgreater-e1 e) env)]
               [v2 (eval-under-env (ifgreater-e2 e) env)]
               [int-comp (lambda (a b) (> (int-num a) (int-num b)))])
           (if (int-comp v1 v2) (eval-under-env (ifgreater-e3 e) env)
               (eval-under-env (ifgreater-e4 e) env)
           ))]
        [(mlet? e)
         (letrec ([var-name (mlet-var e)]
                  [var-val (eval-under-env (mlet-e e) env)])
           (if (string? var-name)
               (let ([new-env (cons (cons var-name var-val) env)])
                 (eval-under-env (mlet-body e) new-env))
               (error (format "~v is not a racket string" var-name))))]
        [(fun? e)
         (letrec ([s1 (fun-nameopt e)]
                  [s2 (fun-formal e)])
           (if (or (string? s1) (not s1))
               (closure env (fun s1 s2 (fun-body e)))
               (error (format "~v is not a valid function" e))))]
        [(apair? e) (apair (eval-under-env (apair-e1 e) env)
                           (eval-under-env (apair-e2 e) env))]
        [(aunit? e) e]
        [(isaunit? e)
         (if (aunit? (eval-under-env (isaunit-e e) env)) (int 1) (int 0))]
        [(fst? e)
         (let ([p (eval-under-env (fst-e e) env)])
           (if (apair? p)
               (apair-e1 p)
               (error (format "~v is not a pair: " p))))]
        [(snd? e)
         (let ([p (eval-under-env (snd-e e) env)])
           (if (apair? p)
               (apair-e2 p)
               (error (format "~v is not a pair: " p))))]
        [(call? e)
         (letrec ([v1 (eval-under-env (call-funexp e) env)]
                  [v2 (eval-under-env (call-actual e) env)])
           (if (closure? v1)
               (letrec ([cenv (closure-env v1)]
                        [cfun (closure-fun v1)]
                        [fname (fun-nameopt cfun)]
                        [fvar (fun-formal cfun)]
                        [fbody (fun-body cfun)])
                 (begin
                   (if (string? fname) (set! cenv (cons (cons fname v1) cenv)) '())
                   (set! cenv (cons (cons fvar v2) cenv))
                   (eval-under-env fbody cenv)))
               (error (format "expect a closure: ~v" v1))))]
        [(closure? e) e]
        [#t (error (format "bad MUPL expression: ~v" e))])))

;; Do NOT change
(define (eval-exp e)
  (eval-under-env e null))

;; Problem 3

(define (ifaunit e1 e2 e3) (ifgreater (isaunit e1) (int 0) e2 e3))

(define (mlet* lstlst e2)
  (if (null? lstlst) e2
      (let ([head (car lstlst)])
        (mlet (car head) (cdr head) (mlet* (cdr lstlst) e2)))))

(define (ifeq e1 e2 e3 e4)
  (mlet* (list (cons "_x" e1) (cons "_y" e2)) (ifgreater (var "_x") (var "_y") e4 (ifgreater (var "_y") (var "_x") e4 e3))))

;; Problem 4
(define mupl-map
  (fun #f "f"   ; a lambda that takes a function f and returns another function g
       (fun "g" "l"
            (ifaunit (var "l") (aunit)
                     (apair (call (var "f") (fst (var "l"))) (call (var "g") (snd (var "l"))))))))


(define mupl-mapAddN
  (mlet "map" mupl-map
        (fun "mupl-mapAddN" "i"
             (call mupl-map (fun #f "x" (add (var "i") (var "x")))))))

;; Challenge Problem

(struct fun-challenge (nameopt formal body freevars) #:transparent) ;; a recursive(?) 1-argument function

;; We will test this function directly, so it must do
;; as described in the assignment
(define (compute-free-vars e) "CHANGE")

;; Do NOT share code with eval-under-env because that will make
;; auto-grading and peer assessment more difficult, so
;; copy most of your interpreter here and make minor changes
(define (eval-under-env-c e env) "CHANGE")

;; Do NOT change this
(define (eval-exp-c e)
  (eval-under-env-c (compute-free-vars e) null))
