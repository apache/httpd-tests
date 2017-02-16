use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 10, need_module 'brotli', need_module 'alias';

my $r;

# GET request against the location with Brotli.
$r = GET("/only_brotli/index.html", "Accept-Encoding" => "br");
ok t_cmp($r->code, 200);
ok t_cmp($r->header("Content-Encoding"), "br", "response Content-Encoding is OK");
if (!defined($r->header("Content-Length"))) {
    t_debug "Content-Length was expected";
    ok 0;
}
if (!defined($r->header("ETag"))) {
    t_debug "ETag field was expected";
    ok 0;
}

# GET request for a zero-length file.
$r = GET("/only_brotli/zero.txt", "Accept-Encoding" => "br");
ok t_cmp($r->code, 200);
ok t_cmp($r->header("Content-Encoding"), "br", "response Content-Encoding is OK");
if (!defined($r->header("Content-Length"))) {
    t_debug "Content-Length was expected";
    ok 0;
}
if (!defined($r->header("ETag"))) {
    t_debug "ETag field was expected";
    ok 0;
}

# HEAD request against the location with Brotli.
$r = HEAD("/only_brotli/index.html", "Accept-Encoding" => "br");
ok t_cmp($r->code, 200);
ok t_cmp($r->header("Content-Encoding"), "br", "response Content-Encoding is OK");
if (!defined($r->header("Content-Length"))) {
    t_debug "Content-Length was expected";
    ok 0;
}
if (!defined($r->header("ETag"))) {
    t_debug "ETag field was expected";
    ok 0;
}

if (have_module('deflate')) {
    # GET request against the location with fallback to deflate (test that
    # Brotli is chosen due to the order in SetOutputFilter).
    $r = GET("/brotli_and_deflate/apache_pb.gif", "Accept-Encoding" => "gzip,br");
    ok t_cmp($r->code, 200);
    ok t_cmp($r->header("Content-Encoding"), "br", "response Content-Encoding is OK");
    if (!defined($r->header("Content-Length"))) {
        t_debug "Content-Length was expected";
        ok 0;
    }
    if (!defined($r->header("ETag"))) {
        t_debug "ETag field was expected";
        ok 0;
    }
    $r = GET("/brotli_and_deflate/apache_pb.gif", "Accept-Encoding" => "gzip");
    ok t_cmp($r->code, 200);
    ok t_cmp($r->header("Content-Encoding"), "gzip", "response Content-Encoding is OK");
    if (!defined($r->header("Content-Length"))) {
        t_debug "Content-Length was expected";
        ok 0;
    }
    if (!defined($r->header("ETag"))) {
        t_debug "ETag field was expected";
        ok 0;
    }
} else {
    skip "skipping tests without mod_deflate" foreach (1..4);
}
