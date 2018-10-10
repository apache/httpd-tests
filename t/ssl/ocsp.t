use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestSSLCA;
use Apache::TestRequest;
use Apache::TestConfig ();

#if keepalives are on, renegotiation not happen again once
#a client cert is presented.  so on test #3, the cert from #2
#will be used.  this test scenerio would never
#happen in real-life, so just disable keepalives here.
Apache::TestRequest::user_agent_keepalive(0);

my $url = '/index.html';

Apache::TestRequest::scheme('https');
Apache::TestRequest::module('ssl_ocsp');

# Requires OpenSSL 1.1, can't find a simple way to test for OCSP
# support in earlier versions without messing around with stderr
my $openssl = Apache::TestSSLCA::openssl();
if (!have_min_apache_version('2.4.26')
    or system("$openssl ocsp 2>/dev/null") == 0) {
    print "1..0 # skip: No OpenSSL or mod_ssl OCSP support";
    exit 0;
}

plan tests => 3, need_lwp;

my $r;

sok {
    $r = GET $url, cert => undef;
    print $r->as_string;
    $r->code != 200;
};

sok {
    $r = GET $url, cert => 'client_ok';
    print $r->as_string;
    $r->code == 200;
};

sok {
    $r = GET $url, cert => 'client_revoked';
    print $r->as_string;
    $r->code != 200 && $r->as_string =~ "alert certificate revoked";
};

