use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, test_module 'test_apr_uri';

my $body = GET_BODY '/test_apr_uri';

ok $body =~ /TOTAL\s+FAILURES\s*=\s*0/;
