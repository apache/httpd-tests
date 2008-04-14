use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Ext-Modules::TestEnv;

plan tests => 1, \&Ext-Modules::TestEnv::has_php4;

## hello.php source:
## <?php echo "Hello World"?>
##
## result should be 'Hello World'

my $result = GET_BODY "/php/hello.php";
ok $result eq 'Hello World';
