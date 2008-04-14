use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

my $result = GET_BODY "/php/globals.php";
ok $result eq "1 5 2 2 10 5  2 5 3 2 10 5  3 5 4 2 \n";
