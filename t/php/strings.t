use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

my $expected = "\"	\\'\\n\\'a\\\\b\\";

my $result = GET_BODY "/php/strings.php";
ok $result eq $expected;
