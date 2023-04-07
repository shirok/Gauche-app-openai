;;;
;;; gauche_app_openai
;;;

(define-module app.openai
  (use gauche.sequence)
  (use gauche.uvector)
  (use gauche.vport)
  (use rfc.base64)
  (use rfc.json)
  (use rfc.http)
  (use text.tr)
  (use util.match)
  (export <openai>
          openai-models
          openai-use-model!

          openai-completions
          openai-chat

          openai-generate-images
          openai-image-saver
          ))
(select-module app.openai)

(define-constant *host* "api.openai.com")

(define-class <openai> ()
  ((api-key :init-keyword :api-key
            :init-form (sys-getenv "OPENAI_API_KEY"))
   (organization :init-keyword :organization
                 :init-form (sys-getenv "OPENAI_ORGANIZATION"))
   (model   :init-keyword :model
            :init-value #f)
   (user    :init-keyword :user
            :init-value #f)
   ))

(define (%ensure openai)
  (unless (~ openai'api-key)
    (error "OpenAI API key is not set.")))

(define (%ensure-model openai model)
  (or model
      (~ openai'model)
      (error "Model must be specified.")))

(define-syntax build-optional-request-map
  (er-macro-transformer
   (^[f r c]
     (define (var->key v)
       (string-tr (symbol->string v) "-" "_"))
     (match f
       [(_ vars ...)
        (quasirename r
          `(cond-list
            ,@(map (^v `(,v (cons ,(var->key v) ,v))) vars)))]))))


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
  (let1 r (%get openai "/v1/models")
    (if (and (pair? r)
             (equal? (assoc-ref r "object") "list"))
      (coerce-to <list> (assoc-ref r "data" '()))
      (error "Unexpected result from /vi/models:" r))))

(define-method openai-use-model! ((openai <openai>) model-name)
  (set! (~ openai'model) model-name))

;;
;; Completions
;;

(define-method openai-completions ((openai <openai>)
                                   :key (model #f)
                                        (prompt #f)
                                        (suffix #f)
                                        (max-tokens #f)
                                        (temperature #f)
                                        (top-p #f)
                                        (n #f)
                                        (stream #f)
                                        (logprobs #f)
                                        (echo #f)
                                        (stop #f)
                                        (presence-penalty #f)
                                        (frequency-penalty #f)
                                        (best-of #f)
                                        (logit-bias #f))
  (%post openai "/v1/completions"
         `(("model" . ,(%ensure-model openai model))
           ,@(build-optional-request-map prompt suffix
                                         max-tokens temperature
                                         top-p n stream logprobs
                                         echo stop presence-penalty
                                         frequency-penalty best-of
                                         logit-bias))))

;;
;; Chat
;;

;; Message format:
;;  ((<role> <content>) ...)
;; where <role> can be :system, :user, or :assistant,
;; and <content> is a string.
(define-method openai-chat ((openai <openai>) messages
                            :key (model #f)
                                 (temperature #f)
                                 (top-p #f)
                                 (n #f)
                                 (stream #f)
                                 (stop #f)
                                 (max-tokens #f)
                                 (presence-penalty #f)
                                 (frequency-penalty #f)
                                 (logit-bias #f))
  (define (messages->map messsages)
    (map-to <vector> (^l (match-let1 (role content) l
                           `(("role" . ,(keyword->string role))
                             ("content" . ,content))))
            messages))
  (%post openai "/v1/chat/completions"
         `(("model" . ,(%ensure-model openai model))
           ("messages" . ,(messages->map messages))
           ,@(build-optional-request-map temperature top-p n stream stop
                                         max-tokens presence-penalty
                                         frequency-penalty logit-bias))))

;;
;; Images
;;

(define (openai-image-saver prefix)
  (^[index type payload]
    (ecase type
      [(data) (rlet1 path #"~|prefix|~|index|.png"
                (with-output-to-file path
                  (cut write-uvector payload)))]
      ;; TODO: Fetch image from url and save it
      [(url)  (rlet1 path #"~|prefix|~|index|.link"
                (with-output-to-file path
                  (cut display payload)))]
      )))

(define-method openai-generate-images ((openai <openai>) prompt
                                       :key (n #f)
                                            (size #f)
                                            (response-format #f)
                                            (handler list))
  (let1 r
      (%post openai "/v1/images/generations"
             `(("prompt" . ,prompt)
               ,@(build-optional-request-map n size response-format)))
    (filter-map
     (^[m ind] (match m
             [(("url" . url) . _) (handler ind 'url url)]
             [(("b64_json" . data) . _)
              (let1 p (open-output-uvector)
                (with-output-to-port p
                  (^[] (with-input-from-string data base64-decode)))
                (handler ind 'data (get-output-uvector p :shared #t)))]
             [((other . payload) . _)
              (warn "Unknown image type: ~S" other)
              (cons other payload)]))
     (coerce-to <list> (assoc-ref r "data" '()))
     (liota))))
