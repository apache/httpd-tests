use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

## add.php source:
## <?php $a=1; $b=2; $c=3; $d=$a+$b+$c; echo $d?>
##
## result should be '6' (1+2+3=6)

my $result = GET_BODY "/php/add.php";
ok $result eq '6';
