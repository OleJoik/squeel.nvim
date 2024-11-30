; inherits: python

(
  string
     (string_start) @_s_start (#match? @_s_start "\"\"\"")
     (string_content) @injection.content 
      (#set! injection.language "sql")
      (#lua-match? @injection.content "^[%s\n]*%-%-%s*[Ss][Qq][Ll]")
     (string_end) @_s_end (#match? @_s_end "\"\"\"")
)
