;;;
;;; Test app.openai
;;;

(use gauche.test)

(test-start "app.openai")
(use app.openai)
(test-module 'app.openai)

;; If you don't want `gosh' to exit with nonzero status even if
;; the test fails, pass #f to :exit-on-failure.
(test-end :exit-on-failure #t)
