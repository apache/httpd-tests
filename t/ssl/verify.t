use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

my $url = '/verify/index.html';

plan tests => 3;

Apache::TestRequest::scheme('https');

my $r;

$r = GET $url, cert => undef;

ok $r->code != 200;
print $r->as_string;

$r = GET $url, cert => 'client_ok';

ok $r->code == 200;
print $r->as_string;

$r = GET $url, cert => 'client_revoked';

ok $r->code != 200;
print $r->as_string;
