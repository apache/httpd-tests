use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

my $expected = <<EXPECT;
i=0
In branch 0
i=1
In branch 1
i=2
In branch 2
i=3
In branch 3
hi
EXPECT

my $result = GET_BODY "/php/switch3.php";
ok $result eq $expected;
