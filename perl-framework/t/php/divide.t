use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

## divide.php source:
## <?php $a=27; $b=3; $c=3; $d=$a/$b/$c; echo $d?>
##
## result should be '3' (27/3/3=3)

my $result = GET_BODY "/php/divide.php";
ok $result eq '3';
