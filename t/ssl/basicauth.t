use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

my $url = '/ssl-fakebasicauth/index.html';

plan tests => 3;

Apache::TestRequest::scheme('https');

ok GET_RC($url, cert => undef) != 200;

ok GET_RC($url, cert => 'client_snakeoil') == 200;

ok GET_RC($url, cert => 'client_ok') == 401;
