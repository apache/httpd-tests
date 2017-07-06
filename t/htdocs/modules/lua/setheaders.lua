function handle(r)
    r.headers_out["X-Header"] = "yes"
    r.headers_out["X-Host"]   = r.headers_in["Host"]
    --[[
    apr_table.set(r.headers_out, "X-Compat", "compat")
    --]]
    r.headers_out["X-Compat"]   = "compat"
end
