use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();
use Apache::TestUtil;

my $url = '/ssl-fakebasicauth/index.html';

plan tests => 3, have_module 'auth';

Apache::TestRequest::scheme('https');

ok t_cmp (500,
          GET_RC($url, cert => undef),
          "Getting $url with no cert"
         );

ok t_cmp (200,
          GET_RC($url, cert => 'client_snakeoil'),
          "Getting $url with client_snakeoil cert"
         );

ok t_cmp (401,
          GET_RC($url, cert => 'client_ok'),
          "Getting $url with client_ok cert"
         );
