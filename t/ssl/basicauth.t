use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();
use Apache::TestUtil;

#if keepalives are on, renegotiation not happen again once
#a client cert is presented.  so on test #3, the cert from #2
#will be used.  this test scenerio would never
#happen in real-life, so just disable keepalives here.
Apache::TestRequest::user_agent_keepalive(0);

my $url = '/ssl-fakebasicauth/index.html';

plan tests => 3, need need_auth, need_lwp;

Apache::TestRequest::scheme('https');

ok t_cmp (GET_RC($url, cert => undef),
          500,
          "Getting $url with no cert"
         );

ok t_cmp (GET_RC($url, cert => 'client_snakeoil'),
          200,
          "Getting $url with client_snakeoil cert"
         );

ok t_cmp (GET_RC($url, cert => 'client_ok'),
          401,
          "Getting $url with client_ok cert"
         );
