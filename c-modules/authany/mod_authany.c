#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

Alias /authany @DocumentRoot@
<Location /authany>
   require user any-user
   AuthType Basic
   AuthName authany
</Location>

#endif

#include "httpd.h"  
#include "http_config.h"  
#include "http_request.h"  
#include "http_protocol.h"  
#include "http_core.h"  
#include "http_main.h" 
#include "http_log.h"  
 
static int require_any_user(request_rec *r)
{
    const apr_array_header_t *requires = ap_requires(r);
    require_line *rq;
    int x;

    if (!requires) {
        return DECLINED;
    }

    rq = (require_line *) requires->elts;

    for (x = 0; x < requires->nelts; x++) {
        const char *line, *requirement;

        line = rq[x].requirement;
        requirement = ap_getword(r->pool, &line, ' ');

        if ((strcmp(requirement, "user") == 0) &&
            (strcmp(line, "any-user") == 0))
        {
            return OK;
        }
    }

    return DECLINED;
}

/* do not accept empty "" strings */
#define strtrue(s) (s && *s)

static int authany_handler(request_rec *r)
{
     const char *sent_pw; 
     int rc = ap_get_basic_auth_pw(r, &sent_pw); 

     if (rc != OK) {
         return rc;
     }

     if (require_any_user(r) != OK) {
         return DECLINED;
     }

     if (!(strtrue(r->user) && strtrue(sent_pw))) {
         ap_note_basic_auth_failure(r);  
         ap_log_rerror(APLOG_MARK, APLOG_NOERRNO|APLOG_ERR, 0, r,
                       "Both a username and password must be provided");
         return HTTP_UNAUTHORIZED;
     }

     return OK;
}

static void authany_register_hooks(apr_pool_t *p)
{
    ap_hook_check_user_id(authany_handler, NULL, NULL, APR_HOOK_FIRST);
    ap_hook_auth_checker(require_any_user, NULL, NULL, APR_HOOK_FIRST);
}

module AP_MODULE_DECLARE_DATA authany_module =
{
    STANDARD20_MODULE_STUFF,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    authany_register_hooks
};
