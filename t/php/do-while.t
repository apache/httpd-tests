use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, have_module 'php4';

my $expected = "321";

my $result = GET_BODY "/php/do-while.php";
ok $result eq $expected;
