#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /echo_post>
   SetHandler echo-post
</Location>

#endif

#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_log.h"
#include "ap_config.h"

static int echo_post_handler(request_rec *r)
{
    int rc;
    long nrd;
    char buff[BUFSIZ];

    if (strcmp(r->handler, "echo-post")) {
        return DECLINED;
    }
    if (r->method_number != M_POST) {
        return DECLINED;
    }

    if ((rc = ap_setup_client_block(r, REQUEST_CHUNKED_ERROR)) != OK) {
        ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO, 0,
                     r->server,
                     "[mod_echo_post] ap_setup_client_block failed: %d", rc);
        return 0;
    }

    if (!ap_should_client_block(r)) {
        return OK;
    }

    if (r->args) {
        ap_rprintf(r, "%d:", (int)r->remaining);
    }

    fprintf(stderr, "[mod_echo_post] going to echo %d bytes\n", (int)r->remaining);

    while ((nrd = ap_get_client_block(r, buff, sizeof(buff))) > 0) {
        fprintf(stderr, "[mod_echo_post] read %ld bytes (wanted %d, remaining=%d)\n",
                nrd, sizeof(buff), (int)r->remaining);
        ap_rwrite(buff, nrd, r);
    }

    fprintf(stderr, "[mod_echo_post] done reading, %d bytes remain\n",
            (int)r->remaining);
    
    return OK;
}

static void echo_post_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(echo_post_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA echo_post_module = {
    STANDARD20_MODULE_STUFF, 
    NULL,                  /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    NULL,                  /* table of config file commands       */
    echo_post_register_hooks  /* register hooks                      */
};

