use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 5;

Apache::TestRequest::scheme('https');

my $url = '/require/asf/index.html';

ok GET_RC($url, cert => undef) != 200;

ok GET_RC($url, cert => 'client_ok') == 200;

ok GET_RC($url, cert => 'client_revoked') != 200;

$url = '/require/snakeoil/index.html';

ok GET_RC($url, cert => 'client_ok') != 200;

ok GET_RC($url, cert => 'client_snakeoil') == 200;

