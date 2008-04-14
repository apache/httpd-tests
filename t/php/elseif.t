use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

my $result = GET_BODY "/php/elseif.php";
ok $result eq "good\n";
