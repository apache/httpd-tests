use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

## ops.php source:
## <?php $a=8; $b=4; $c=8; echo $a|$b&$c?>
##
## result should be '8'

my $result = GET_BODY "/php/ops.php";
ok $result eq '8';
