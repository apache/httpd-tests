use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, have_module 'php4';

my $result = GET_BODY "/php/nestif.php";
ok $result eq "good\n";
