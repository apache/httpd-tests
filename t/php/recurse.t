use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need_php;

my $result = GET_BODY "/php/recurse.php";
ok $result eq "1 2 3 4 5 6 7 8 9 \n";
