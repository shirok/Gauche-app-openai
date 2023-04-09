# OpenAI API utility for Gauche

A simple OpenAI API wrapper.

Usage:
```
(use app.openai)

(define oai (make <openai> :api-key "YOUR_API_KEY" :model "gpt-3.5-turbo"))

(openai-chat oai
  '((:system "You are a movie producer.")
    (:user "Write a synopsis of a film based on Shakespeare's Much Ado About Nothing, but taking place in 21c.")))
```

It's still in early stage of development; API may change.

## `<openai>` object and the API key

An instance of `<openai>` is used to access OpenAI API.  It holds the API
key and some other states.  You do need your API key to access OpenAI.

When you instantiate `<openai>`, you can give the API key with
`:api-key` initarg.  If `:api-key` isn't given, the constructor
checks the environment varaible `OPENAI_API_KEY`.

Some OpenAI API requires `model` parameter.  You can give it in
individual API call, but you can also set the default model
in the `model` slot of an `<openai>` object.

You can also set `organizaiton` slot optonally; if set, it is sent
to OpenAPI as `openai-organization` request header.
