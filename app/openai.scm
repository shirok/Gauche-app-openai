;;;
;;; gauche_app_openai
;;;

(define-module app.openai
  (use rfc.json)
  (use rfc.http)
  (export <openai>
          openai-models
          ))
(select-module app.openai)

(define-constant *host* "api.openai.com")

(define-class <openai> ()
  ((api-key :init-keyword :api-key
            :init-form (sys-getenv "OPENAI_API_KEY"))
   (organization :init-keyword :organization
                 :init-form (sys-getenv "OPENAI_ORGANIZATION"))
   ))

(define (%ensure openai)
  (unless (~ openai'api-key)
    (error "OpenAI API key is not set.")))

(define (%get openai path)
  (%ensure openai)
  (receive (status hdrs body)
      (http-get *host* path
                :secure #t
                :authorization #"Bearer ~(~ openai'api-key)"
                :openai-organization (~ openai'organization))
    (unless (equal? status "200")
      (errorf "OpenAI API error (~a): ~a" status body))
    (parse-json-string body)))

(define (%post openai path json-body)
  (%ensure openai)
  (receive (status hdrs body)
      (http-post *host* path (construct-json-string json-body)
                 :secure #t
                 :authorization #"Bearer ~(~ openai'api-key)"
                 :openai-organization (~ openai'organization)
                 :content-type "application/json")
    (unless (equal? status "200")
      (errorf "OpenAI API error (~a): ~a" status body))
    (parse-json-string body)))

;;
;; Models
;;

(define-method openai-models ((openai <openai>))
  (%get openai "/v1/models"))
