use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();
use Apache::TestUtil;

# check fake authentication using mod_auth_anon
# no cert should fail but the presence of any cert
# should pass.  see also t/ssl/basicauth.t

my $url = '/ssl-fakebasicauth2/index.html';

plan tests => 3, need need_auth,
                      need_module('mod_authn_anon'),
                      need_min_apache_version(2.1);

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
          200,
          "Getting $url with client_ok cert"
         );
