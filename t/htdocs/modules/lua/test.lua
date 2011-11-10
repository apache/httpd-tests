-- example handler

require "string"

function handle_hello(r)
    r.content_type = "text/plain"
    r:puts("Hello Lua World!\n")
end

function handle_version(r)
  r:puts(apache2.version)
end

function handle_method(r)
   r:puts(r.method)
end

function handle_201(r)
   r.status = 201
end

function handle_https(r)
   if r.is_https then
      r:puts("yep")
   else
      r:puts("nope")
   end
end
