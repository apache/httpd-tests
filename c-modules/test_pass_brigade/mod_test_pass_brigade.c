#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /test_pass_brigade>
   SetHandler test_pass_brigade
</Location>

#endif

#define APACHE_HTTPD_TEST_HANDLER test_pass_brigade_handler

#include "apache_httpd_test.h"

#include "apr_buckets.h"

/*
 * mainly for testing / researching core_output_filter buffering
 */

static int test_pass_brigade_handler(request_rec *r)
{
    const char *args = r->args;
    long total=0, remaining=1;
    char *buff, *endptr;
    int buff_size = 8192;

    if (strcmp(r->handler, "test_pass_brigade")) {
        return DECLINED;
    }
    if (r->method_number != M_GET) {
        return DECLINED;
    }

    if (args) {
        buff_size = strtol(args, &endptr, 0);

        if (endptr && *endptr == ',') {
            ++endptr;
            remaining = strtol(endptr, &endptr, 0);
        }
    }

    fprintf(stderr, "[mod_test_pass_brigade] "
            "going to echo %ld bytes with buffer size=%d\n",
            remaining, buff_size);

    buff = malloc(buff_size);
    memset(buff, 'a', buff_size);

    while (total < remaining) {
        int left = (remaining - total);
        int len = left <= buff_size ? left : buff_size;
        apr_bucket_brigade *bb = apr_brigade_create(r->pool);
        apr_bucket *bucket = apr_bucket_heap_create(buff, len, 1);
        apr_status_t status;

        APR_BRIGADE_INSERT_TAIL(bb, bucket);

        status = ap_pass_brigade(r->output_filters->next, bb);

        if (status != APR_SUCCESS) {
            apr_brigade_destroy(bb);
            ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO,
                         status, r->server,
                         "[mod_test_pass_brigade] ap_pass_brigade failed");
            free(buff);
            return HTTP_INTERNAL_SERVER_ERROR;
        }

        total += len;

        fprintf(stderr, "[mod_test_pass_brigade] wrote %d of %d bytes\n",
                len, len);
    }
    
    fprintf(stderr,
            "[mod_test_pass_brigade] done writing %ld of %ld bytes\n",
            total, remaining);

    free(buff);    
    return OK;
}

APACHE_HTTPD_TEST_MODULE(test_pass_brigade);

