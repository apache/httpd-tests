use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

plan tests => 17, need_module 'proxy';

Apache::TestRequest::module("proxy_http_reverse");
Apache::TestRequest::user_agent(requests_redirectable => 0);

my $r = GET("/reverse/");
ok t_cmp($r->code, 200, "reverse proxy to index.html");
ok t_cmp($r->content, qr/^welcome to /, "reverse proxied body");

if (have_cgi) {
    $r = GET("/reverse/modules/cgi/env.pl");
    ok t_cmp($r->code, 200, "reverse proxy to env.pl");
    ok t_cmp($r->content, qr/^APACHE_TEST_HOSTNAME = /, "reverse proxied env.pl response");
    
    $r = GET("/reverse/modules/cgi/env.pl?reverse-proxy");
    ok t_cmp($r->code, 200, "reverse proxy with query string");
    ok t_cmp($r->content, qr/QUERY_STRING = reverse-proxy\n/s, "reverse proxied query string OK");

    $r = GET("/reverse/modules/cgi/nph-dripfeed.pl");
    ok t_cmp($r->code, 200, "reverse proxy to dripfeed CGI");
    ok t_cmp($r->content, "abcdef", "reverse proxied to dripfeed CGI content OK");

    if (have_min_apache_version('2.1.0')) {
        $r = GET("/reverse/modules/cgi/nph-102.pl");
        ok t_cmp($r->code, 200, "reverse proxy to nph-102");
        ok t_cmp($r->content, "this is nph-stdout", "reverse proxy 102 response");
    } else {
        skip "skipping tests with httpd <2.1.0" foreach (1..2);
    }
    $r = GET("/reverse/modules/cgi/nph-interim1.pl");
    ok t_cmp($r->code, 200, "small number of interim responses - CVE-2008-2364");

    $r = GET("/reverse/modules/cgi/nph-interim2.pl");
    ok t_cmp($r->code, 502, "large number of interim responses - CVE-2008-2364");

} else {
    skip "skipping tests without CGI module" foreach (1..10);
}

if (have_min_apache_version('2.0.55')) {
    # trigger the "proxy decodes abs_path issue": with the bug present, the
    # proxy URI-decodes on the way through, so the origin server receives
    # an abs_path of "/reverse/nonesuch/file%", which it fails to parse and
    # returns a 400 response.
    $r = GET("/reverse/nonesuch/file%25");
    ok t_cmp($r->code, 404, "reverse proxy URI decoding issue, PR 15207");
} else {
    skip "skipping PR 15207 test with httpd < 2.0.55";
}

$r = GET("/reverse/notproxy/local.html");
ok t_cmp($r->code, 200, "ProxyPass not-proxied request");
my $c = $r->content;
chomp $c;
ok t_cmp($c, "hello world", "ProxyPass not-proxied content OK");

if (have_module('alias')) {
    $r = GET("/reverse/perm");
    ok t_cmp($r->code, 301, "reverse proxy of redirect");
    ok t_cmp($r->header("Location"), qr{http://[^/]*/reverse/alias}, "reverse proxy rewrote redirect");
} else {
    skip "skipping tests without mod_alias" foreach (1..2);
}

