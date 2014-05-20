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

;; a closure is not in "source" programs; it is what functions evaluate to
(struct closure (env fun) #:transparent) 

;; Problem 1

(define (racketlist->mupllist rktlst)
  (if (null? rktlst)
      (aunit)
      (apair (car rktlst) (racketlist->mupllist (cdr rktlst)))))

(define (mupllist->racketlist mupllst)
  (if (apair? mupllst)
      (cons (apair-e1 mupllst) (mupllist->racketlist (apair-e2 mupllst)))
      null))
      
;; Problem 2

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
        [(closure? e) e]
        [(aunit? e) e]
        [(ifgreater? e)
         (let ([v1 (eval-under-env (ifgreater-e1 e) env)]
               [v2 (eval-under-env (ifgreater-e2 e) env)])
           (if (and (int? v1)
                    (int? v2))
               (if (> (int-num v1) (int-num v2))
                   (eval-under-env (ifgreater-e3 e) env)
                   (eval-under-env (ifgreater-e4 e) env))
               (error "MUPL comparasion applied to non-number")))]
        [(fun? e) (closure env e)]
        [(call? e)
         (let ([v1 (eval-under-env (call-funexp e) env)]
               [v2 (eval-under-env (call-actual e) env)])
           (if (closure? v1)
               (eval-under-env (fun-body (closure-fun v1))
                               (if (fun-nameopt (closure-fun v1))
                                   (append (list (cons (fun-formal (closure-fun v1)) v2)
                                                 (cons (fun-nameopt (closure-fun v1)) v1))
                                           (closure-env v1))
                                   (cons (cons (fun-formal (closure-fun v1)) v2) (closure-env v1))))
               (error "MUPL call applied to non-closure")))]
        [(mlet? e)
         (let ([v1 (eval-under-env (mlet-e e) env)])
           (eval-under-env (mlet-body e) (cons (cons (mlet-var e) v1) env)))]
        [(apair? e)
         (let ([v1 (eval-under-env (apair-e1 e) env)]
               [v2 (eval-under-env (apair-e2 e) env)])
           (apair v1 v2))]
        [(fst? e)
         (let ([v1 (eval-under-env (fst-e e) env)])
           (if (apair? v1)
               (apair-e1 v1)
               (error "MUPL fst applied to non-pair")))]
        [(snd? e)
         (let ([v1 (eval-under-env (snd-e e) env)])
           (if (apair? v1)
               (apair-e2 v1)
               (error "MUPL snd applied to non-pair")))]
        [(isaunit? e)
         (let ([v1 (eval-under-env (isaunit-e e) env)])
           (if (aunit? v1)
               (int 1)
               (int 0)))]
        [#t (error (format "bad MUPL expression: ~v" e))]))

;; Do NOT change
(define (eval-exp e)
  (eval-under-env e null))
        
;; Problem 3

(define (ifaunit e1 e2 e3) (ifgreater (isaunit e1) (int 0)
                                      e2
                                      e3))

(define (mlet* lstlst e2) (mlet (car (car lstlst)) (cdr (car lstlst))
                                (if (null? (cdr lstlst))
                                    e2
                                    (mlet* (cdr lstlst) e2))))

(define (ifeq e1 e2 e3 e4) (mlet* (list (cons "_x" e1) (cons "_y" e2))
                                  (ifgreater (var "_x") (var "_y")
                                             e4
                                             (ifgreater (var "_y") (var "_x")
                                                        e4
                                                        e3))))

;; Problem 4

(define mupl-map (fun "mupl-map" "f"
                      (fun #f "xs"
                           (ifaunit (var "xs")
                                    (aunit)
                                    (apair (call (var "f") (fst (var "xs"))) (call (call (var "mupl-map") (var "f")) (snd (var "xs"))))))))

(define mupl-mapAddN 
  (mlet "map" mupl-map
        (fun #f "i" (call (var "map") (fun #f "x" (add (var "x") (var "i")))))))

;; Challenge Problem

(struct fun-challenge (nameopt formal body freevars) #:transparent) ;; a recursive(?) 1-argument function

;; We will test this function directly, so it must do
;; as described in the assignment
(define (free-vars e)
  (cond [(var? e) (set (var-string e))]
        [(int? e) (set)]
        [(add? e) (set-union (free-vars (add-e1 e)) (free-vars (add-e2 e)))]
        [(ifgreater? e) (set-union (free-vars (ifgreater-e1 e)) (free-vars (ifgreater-e2 e)) (free-vars (ifgreater-e3 e)) (free-vars (ifgreater-e4 e)))]
        [(fun? e) (if (fun-nameopt e) (set-remove (set-remove (free-vars (fun-body e)) (fun-formal e)) (fun-nameopt e)) (set-remove (free-vars (fun-body e)) (fun-formal e)))]
        [(call? e) (set-union (free-vars (call-funexp e)) (free-vars (call-actual e)))]
        [(mlet? e) (set-union (free-vars (mlet-e e)) (set-remove (free-vars (mlet-body e)) (mlet-var e)))]
        [(apair? e) (set-union (free-vars (apair-e1 e)) (free-vars (apair-e2 e)))]
        [(fst? e) (free-vars (fst-e e))]
        [(snd? e) (free-vars (snd-e e))]
        [(aunit? e) (set)]
        [(isaunit? e) (free-vars (isaunit-e e))]
        [#t (error (format "bad MUPL expression: ~v" e))]))
(define (compute-free-vars e)
  (cond [(var? e) e]
        [(int? e) e]
        [(add? e) (add (compute-free-vars (add-e1 e)) (compute-free-vars (add-e2 e)))]
        [(ifgreater? e) (ifgreater (compute-free-vars (ifgreater-e1 e)) (compute-free-vars (ifgreater-e2 e)) (compute-free-vars (ifgreater-e3 e)) (compute-free-vars (ifgreater-e4 e)))]
        [(fun? e) (fun-challenge (fun-nameopt e) (fun-formal e) (compute-free-vars (fun-body e)) (free-vars e))]
        [(call? e) (call (compute-free-vars (call-funexp e)) (compute-free-vars (call-actual e)))]
        [(mlet? e) (mlet (mlet-var e) (compute-free-vars (mlet-e e)) (compute-free-vars (mlet-body e)))]
        [(apair? e) (apair (compute-free-vars (apair-e1 e)) (compute-free-vars (apair-e2 e)))]
        [(fst? e) (fst (compute-free-vars (fst-e e)))]
        [(snd? e) (snd (compute-free-vars (snd-e e)))]
        [(aunit? e) e]
        [(isaunit? e) (isaunit (compute-free-vars (isaunit-e e)))]
        [#t (error (format "bad MUPL expression: ~v" e))]))

;; Do NOT share code with eval-under-env because that will make grading
;; more difficult, so copy most of your interpreter here and make minor changes
(define (eval-under-env-c e env)
  (cond [(var? e)
         (envlookup env (var-string e))]
        [(add? e) 
         (let ([v1 (eval-under-env-c (add-e1 e) env)]
               [v2 (eval-under-env-c (add-e2 e) env)])
           (if (and (int? v1)
                    (int? v2))
               (int (+ (int-num v1) 
                       (int-num v2)))
               (error "MUPL addition applied to non-number")))]
        [(int? e) e]
        [(closure? e) e]
        [(aunit? e) e]
        [(ifgreater? e)
         (let ([v1 (eval-under-env-c (ifgreater-e1 e) env)]
               [v2 (eval-under-env-c (ifgreater-e2 e) env)])
           (if (and (int? v1)
                    (int? v2))
               (if (> (int-num v1) (int-num v2))
                   (eval-under-env-c (ifgreater-e3 e) env)
                   (eval-under-env-c (ifgreater-e4 e) env))
               (error "MUPL comparasion applied to non-number")))]
        [(fun-challenge? e) (closure (filter (lambda (x) (set-member? (fun-challenge-freevars e) (car x))) env) e)]
        [(call? e)
         (let ([v1 (eval-under-env-c (call-funexp e) env)]
               [v2 (eval-under-env-c (call-actual e) env)])
           (if (closure? v1)
               (eval-under-env-c (fun-challenge-body (closure-fun v1))
                               (if (fun-challenge-nameopt (closure-fun v1))
                                   (append (list (cons (fun-challenge-formal (closure-fun v1)) v2)
                                                 (cons (fun-challenge-nameopt (closure-fun v1)) v1))
                                           (closure-env v1))
                                   (cons (cons (fun-challenge-formal (closure-fun v1)) v2) (closure-env v1))))
               (error "MUPL call applied to non-closure")))]
        [(mlet? e)
         (let ([v1 (eval-under-env-c (mlet-e e) env)])
           (eval-under-env-c (mlet-body e) (cons (cons (mlet-var e) v1) env)))]
        [(apair? e)
         (let ([v1 (eval-under-env-c (apair-e1 e) env)]
               [v2 (eval-under-env-c (apair-e2 e) env)])
           (apair v1 v2))]
        [(fst? e)
         (let ([v1 (eval-under-env-c (fst-e e) env)])
           (if (apair? v1)
               (apair-e1 v1)
               (error "MUPL fst applied to non-pair")))]
        [(snd? e)
         (let ([v1 (eval-under-env-c (snd-e e) env)])
           (if (apair? v1)
               (apair-e2 v1)
               (error "MUPL snd applied to non-pair")))]
        [(isaunit? e)
         (let ([v1 (eval-under-env-c (isaunit-e e) env)])
           (if (aunit? v1)
               (int 1)
               (int 0)))]
        [#t (error (format "bad MUPL expression: ~v" e))]))

;; Do NOT change this
(define (eval-exp-c e)
  (eval-under-env-c (compute-free-vars e) null))