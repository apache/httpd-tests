use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## testing eval function

plan tests => 1, have_module 'php4';

my $expected = <<EXPECT;
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
hey, this is a regular echo'd eval()
hey, this is a function inside an eval()!
EXPECT

my $result = GET_BODY "/php/eval4.php";
ok $result eq $expected;
