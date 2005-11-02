use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#if keepalives are on, renegotiation not happen again once
#a client cert is presented.  so on test #3, the cert from #2
#will be used.  this test scenerio would never
#happen in real-life, so just disable keepalives here.
Apache::TestRequest::user_agent_keepalive(0);

plan tests => 5, need_lwp;

Apache::TestRequest::scheme('https');

my $url = '/require/asf/index.html';

ok GET_RC($url, cert => undef) != 200;

ok GET_RC($url, cert => 'client_ok') == 200;

ok GET_RC($url, cert => 'client_revoked') != 200;

$url = '/require/snakeoil/index.html';

ok GET_RC($url, cert => 'client_ok') != 200;

ok GET_RC($url, cert => 'client_snakeoil') == 200;

