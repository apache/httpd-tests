use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

## multiply.php source:
## <?php $a=2; $b=4; $c=8; $d=$a*$b*$c; echo $d?>
##
## result should be '64' (2*4*8=64)

my $result = GET_BODY "/php/multiply.php";
ok $result eq '64';
