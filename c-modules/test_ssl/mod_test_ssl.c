#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /test_ssl_var_lookup>
   SetHandler test-ssl-var-lookup
</Location>

#endif

#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_log.h"
#include "ap_config.h"
#include "apr_optional.h"

#if 0
/* if you have ssl installed, just need to include this file */
#include "mod_ssl.h"

#else

/* but for testing purposes, we'll hardcode the required stuff
 * that mod_ssl.h normally would
 */

char *ssl_var_lookup(apr_pool_t *p, server_rec *s, conn_rec *c,
                     request_rec *r, char *var);

APR_DECLARE_OPTIONAL_FN(char *, ssl_var_lookup,
                        (apr_pool_t *, server_rec *,
                         conn_rec *, request_rec *,
                         char *));

#endif

static APR_OPTIONAL_FN_TYPE(ssl_var_lookup) *var_lookup;

static void import_ssl_var_lookup(void)
{
    var_lookup = APR_RETRIEVE_OPTIONAL_FN(ssl_var_lookup);
}

static int test_ssl_var_lookup(request_rec *r)
{
    char *value;

    if (strcmp(r->handler, "test-ssl-var-lookup")) {
        return DECLINED;
    }

    if (r->method_number != M_GET) {
        return DECLINED;
    }

    if (!r->args) {
        ap_rputs("no query", r);
        return OK;
    }

    if (!var_lookup) {
        ap_rputs("ssl_var_lookup is not available", r);
        return OK;
    }

    value = var_lookup(r->pool, r->server,
                       r->connection, r, r->args);

    if (value && *value) {
        ap_rputs(value, r);
    }
    else {
        ap_rputs("NULL", r);
    }

    return OK;
}

static void test_ssl_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(test_ssl_var_lookup, NULL, NULL, APR_HOOK_MIDDLE);
    ap_hook_optional_fn_retrieve(import_ssl_var_lookup,
                                 NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA test_ssl_module = {
    STANDARD20_MODULE_STUFF, 
    NULL,                  /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    NULL,                  /* table of config file commands       */
    test_ssl_register_hooks  /* register hooks                      */
};

