use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

my $expected = "321";

my $result = GET_BODY "/php/do-while.php";
ok $result eq $expected;
