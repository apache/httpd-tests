use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, test_module 'php4';

my $result = GET_BODY "/php/while.php";
ok $result eq '123456789';
