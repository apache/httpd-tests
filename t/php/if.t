use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need_php;

my $result = GET_BODY "/php/if.php";
ok $result eq 'Yes';
