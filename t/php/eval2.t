use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

## testing eval function inside user function

plan tests => 1, \&ExtModules::TestEnv::has_php4;

my $expected = "Hello";

my $result = GET_BODY "/php/eval2.php";
ok $result eq $expected;
