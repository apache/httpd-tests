#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /input_body_filter>
  SetHandler input-body-filter
  InputBodyFilter On
</Location>

#endif

#include "httpd.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_request.h"
#include "http_log.h"
#include "ap_config.h"
#include "util_filter.h"
#include "apr_buckets.h"
#include "apr_strings.h"

module AP_MODULE_DECLARE_DATA input_body_filter_module;

#define INPUT_BODY_FILTER_NAME "INPUT_BODY_FILTER"

typedef struct {
    int enabled;
} input_body_filter_dcfg_t;

static void *input_body_filter_dcfg_create(apr_pool_t *p, char *dummy)
{
    input_body_filter_dcfg_t *dcfg =
        (input_body_filter_dcfg_t *)apr_pcalloc(p, sizeof(*dcfg));

    return dcfg;
}

static int input_body_filter_fixup_handler(request_rec *r)
{
    if ((r->method_number == M_POST) && r->handler &&
        !strcmp(r->handler, "input-body-filter"))
    {
        r->handler = "echo-post";
    }

    return OK;
}

static int input_body_filter_response_handler(request_rec *r)
{
    if (strcmp(r->handler, "echo-post")) {
        return DECLINED;
    }

    if (r->method_number != M_POST) {
        ap_rputs("1..1\nok 1\n", r);
        return OK;
    }
    else {
        return DECLINED;
    }
}

static void reverse_string(char *string, int len)
{
    register char *up, *down;
    register unsigned char tmp;

    up = string;
    down = string + len - 1;

    while (down > up) {
        tmp = *up;
        *up++ = *down;
        *down-- = tmp;
    }
}

static int input_body_filter_handler(ap_filter_t *f, apr_bucket_brigade *bb, 
                                     ap_input_mode_t mode, apr_off_t *readbytes)
{
    apr_status_t rv;
    apr_pool_t *p = f->r->pool;

    if (APR_BRIGADE_EMPTY(bb)) {
        rv = ap_get_brigade(f->next, bb, mode, readbytes);
        if (rv != APR_SUCCESS) {
            return rv;
        }
    }

    while (!APR_BRIGADE_EMPTY(bb)) {
        const char *data;
        apr_size_t len;
        apr_bucket *bucket;

        bucket = APR_BRIGADE_FIRST(bb);
        rv = apr_bucket_read(bucket, &data, &len, mode);

        if (rv != APR_SUCCESS) {
            return rv;
        }

        APR_BUCKET_REMOVE(bucket);

        if (len) {
            char *reversed = apr_pstrndup(p, data, len);
            reverse_string(reversed, len);
            bucket = apr_bucket_pool_create(reversed, len, p);
        }

        APR_BRIGADE_INSERT_TAIL(bb, bucket);

        if (APR_BUCKET_IS_EOS(bucket)) {
            break;
        }
    }

    return OK;
}

static void input_body_filter_insert_filter(request_rec *r)
{
    input_body_filter_dcfg_t *dcfg =
        ap_get_module_config(r->per_dir_config, 
                             &input_body_filter_module);

    if (dcfg->enabled) {
        ap_add_input_filter(INPUT_BODY_FILTER_NAME, NULL, r, NULL);
    }
}

static void input_body_filter_register_hooks(apr_pool_t *p)
{
    ap_hook_fixups(input_body_filter_fixup_handler,
                  NULL, NULL, APR_HOOK_MIDDLE);

    ap_hook_handler(input_body_filter_response_handler,
                    NULL, NULL, APR_HOOK_MIDDLE);

    ap_hook_insert_filter(input_body_filter_insert_filter,
                          NULL, NULL, APR_HOOK_MIDDLE);

    ap_register_input_filter(INPUT_BODY_FILTER_NAME,
                             input_body_filter_handler, 
                             AP_FTYPE_CONTENT);  
}

static const command_rec input_body_filter_cmds[] = {
    AP_INIT_FLAG("InputBodyFilter", ap_set_flag_slot,
                 XtOffsetOf(input_body_filter_dcfg_t, enabled),
                 OR_ALL, "Enable input body filter"),
    { NULL }
};

module AP_MODULE_DECLARE_DATA input_body_filter_module = {
    STANDARD20_MODULE_STUFF, 
    input_body_filter_dcfg_create, /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    input_body_filter_cmds,   /* table of config file commands       */
    input_body_filter_register_hooks  /* register hooks                      */
};

