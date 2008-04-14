use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

my $expected = <<EXPECT;
zero
one
2
3
4
5
6
7
8
9
zero
one
2
3
4
5
6
7
8
9
zero
one
2
3
4
5
6
7
8
9
EXPECT

my $result = GET_BODY "/php/switch4.php";
ok $result eq $expected;
