#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /test_rwrite>
   SetHandler test-rwrite
</Location>

#endif

#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_log.h"
#include "ap_config.h"

static int test_rwrite_handler(request_rec *r)
{
    long total=0, remaining=1;
    char buff[BUFSIZ];

    if (strcmp(r->handler, "test-rwrite")) {
        return DECLINED;
    }
    if (r->method_number != M_GET) {
        return DECLINED;
    }

    if (r->args) {
        remaining = atol(r->args);
    }

    fprintf(stderr, "[mod_test_rwrite] going to echo %ld bytes\n",
            remaining);

    memset(buff, 'a', sizeof(buff));

    while (total < remaining) {
        int left = (remaining - total);
        int len = left <= sizeof(buff) ? left : sizeof(buff);
        long nrd = ap_rwrite(buff, len, r);
        total += nrd;

        fprintf(stderr, "[mod_test_rwrite] wrote %ld of %d bytes\n",
                nrd, len);
    }
    
    fprintf(stderr,
            "[mod_test_rwrite] done writing %ld of %ld bytes\n",
            total, remaining);
    
    return OK;
}

static void test_rwrite_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(test_rwrite_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA test_rwrite_module = {
    STANDARD20_MODULE_STUFF, 
    NULL,                  /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    NULL,                  /* table of config file commands       */
    test_rwrite_register_hooks  /* register hooks                      */
};

