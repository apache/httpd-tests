use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need_php4;

my $result = GET_BODY "/php/param.php";
ok $result eq "3\n";
