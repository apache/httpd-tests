use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

my $expected = <<EXPECT;
&lt;&gt;&quot;&amp;åÄ
&lt;&gt;&quot;&amp;&aring;&Auml;
EXPECT

my $result = GET_BODY "/php/strings4.php";

ok $result eq $expected;
