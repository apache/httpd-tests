use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, test_module 'php4';

my $expected = "\"	\\'\\n\\'a\\\\b\\";

my $result = GET_BODY "/php/strings.php";
ok $result eq $expected;
