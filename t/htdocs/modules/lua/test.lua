-- example handler

require "string"

function handle_hello(r)
    r.content_type = "text/plain"
    r:puts("Hello Lua World!\n")
end

function handle_version(r)
  r:puts(apache2.version)
end

function handle_print(r)
  r:puts("fish");
end
