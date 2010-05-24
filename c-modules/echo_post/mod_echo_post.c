#if CONFIG_FOR_HTTPD_TEST

<Location /echo_post>
   SetHandler echo_post
</Location>

#endif

#define APACHE_HTTPD_TEST_HANDLER echo_post_handler

#include "apache_httpd_test.h"

static int echo_post_handler(request_rec *r)
{
    int rc;
    long nrd, total = 0;
    char buff[BUFSIZ];

    if (strcmp(r->handler, "echo_post")) {
        return DECLINED;
    }
    if (r->method_number != M_POST) {
        return DECLINED;
    }

    if ((rc = ap_setup_client_block(r, REQUEST_CHUNKED_ERROR)) != OK) {
        ap_log_error(APLOG_MARK, APLOG_ERR|APLOG_NOERRNO,
#ifdef APACHE2
                     0,
#endif /* APACHE2 */
                     r->server,
                     "[mod_echo_post] ap_setup_client_block failed: %d", rc);
        return 0;
    }

    if (!ap_should_client_block(r)) {
        return OK;
    }

#ifdef APACHE1
    ap_send_http_header(r);
#endif
    
    if (r->args) {
        ap_rprintf(r, "%" APR_OFF_T_FMT ":", r->remaining);
    }

    ap_log_rerror(APLOG_MARK, APLOG_DEBUG, 0, r,
                  "[mod_echo_post] going to echo %" APR_OFF_T_FMT " bytes",
                  r->remaining);

    while ((nrd = ap_get_client_block(r, buff, sizeof(buff))) > 0) {
        ap_log_rerror(APLOG_MARK, APLOG_DEBUG, 0, r,
                      "[mod_echo_post] read %ld bytes (wanted %" APR_SIZE_T_FMT 
                      ", remaining=%" APR_OFF_T_FMT ")",
                      nrd, sizeof(buff), r->remaining);
        ap_rwrite(buff, nrd, r);
        total += nrd;
    }

    if (nrd < 0) {
        ap_rputs("!!!ERROR!!!", r);
        ap_log_rerror(APLOG_MARK, APLOG_DEBUG, 0, r,
                      "[mod_echo_post] ap_get_client_block got error");
    }

    ap_log_rerror(APLOG_MARK, APLOG_DEBUG, 0, r,
            "[mod_echo_post] done reading %ld bytes, %" APR_OFF_T_FMT " bytes remain",
            total, r->remaining);
    
    return OK;
}

APACHE_HTTPD_TEST_MODULE(echo_post);
