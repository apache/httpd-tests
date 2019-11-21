use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use IO::Socket::SSL;

# This is the equivalent of pr12355.t for TLSv1.3.

Apache::TestRequest::user_agent(ssl_opts => {SSL_version => 'TLSv13'});
Apache::TestRequest::scheme('https');
Apache::TestRequest::user_agent_keepalive(1);

my $has_pha = defined &IO::Socket::SSL::can_pha &&
    IO::Socket::SSL::can_pha() ? 1 : 0;

my $r = GET "/";

if (!$r->is_success) {
    print "1..0 # skip: TLSv1.3 not supported or PHA not supported";
    exit 0;
}

if (!$has_pha) {
    print "1..0 # skip: PHA not supported in IO::Socket::SSL";
    exit 0;
}

plan tests => 3;

$r = GET("/verify/", cert => undef);
ok t_cmp($r->code, 403, "access must be denied without client certificate");

# Send a series of POST requests with varying size request bodies.
# Alternate between the location which requires a AES128-SHA ciphersuite
# and one which requires AES256-SHA; mod_ssl will attempt to perform the
# renegotiation between each request, and hence needs to perform the
# buffering of request body data.

$r = POST("/verify/modules/cgi/perl_echo.pl", content => 'x'x10000,
          cert => 'client_ok');

ok t_cmp($r->code, 200, "PHA works with POST body");
ok t_cmp($r->content, $r->request->content, "request body matches response");
