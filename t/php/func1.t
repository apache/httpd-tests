use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

## func1.php source:
## <?php echo strlen("abcdef")?>
##
## result should be '6' 

my $result = GET_BODY "/php/func1.php";
ok $result eq '6';
