use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## testing eval function

plan tests => 1, test_module 'php4';

my $expected = "Hello";

my $result = GET_BODY "/php/eval.php";
ok $result eq $expected;
