#if CONFIG_FOR_HTTPD_TEST

<Location /test_rwrite>
   SetHandler test_rwrite
</Location>

#endif

#define APACHE_HTTPD_TEST_HANDLER test_rwrite_handler

#include "apache_httpd_test.h"

static int test_rwrite_handler(request_rec *r)
{
    long total=0, remaining=1;
    char buff[BUFSIZ];

    if (strcmp(r->handler, "test_rwrite")) {
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

APACHE_HTTPD_TEST_MODULE(test_rwrite);

