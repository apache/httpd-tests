use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

my $result = GET_BODY "/php/recurse.php";
ok $result eq "1 2 3 4 5 6 7 8 9 \n";
