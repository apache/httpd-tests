use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

my $expected = <<EXPECT;
This is class foo
a = 2
b = 5
10
-----
This is class bar
a = 4
b = 3
c = 12
12
EXPECT

my $result = GET_BODY "/php/inheritance.php";
ok $result eq $expected
