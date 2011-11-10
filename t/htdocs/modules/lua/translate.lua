require 'apache2'

function translate_name(r)
    if r.uri == "/modules/lua/translate-me" then
        r.uri = "/modules/lua/test_hello"
        return apache2.DECLINED
    end
    return apache2.DECLINED
end
