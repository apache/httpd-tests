use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

plan tests => 6, need_module 'proxy';

Apache::TestRequest::module("proxy_http_reverse");

my $r = GET("/reverse/");
ok t_cmp($r->code, 200, "reverse proxy to index.html");
ok t_cmp($r->content, qr/^welcome to /, "reverse proxied body");

$r = GET("/reverse/modules/cgi/env.pl");
ok t_cmp($r->code, 200, "reverse proxy to env.pl");
ok t_cmp($r->content, qr/^APACHE_TEST_HOSTNAME = /, "reverse proxied env.pl response");

$r = GET("/reverse/modules/cgi/env.pl?reverse-proxy");
ok t_cmp($r->code, 200, "reverse proxy with query string");
ok t_cmp($r->content, qr/QUERY_STRING = reverse-proxy\n/s, "reverse proxied query string OK");

