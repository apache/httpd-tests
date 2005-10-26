use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1, need 'rewrite';

my $rc;

$rc = GET_RC "/security/CAN-2003-0542/nonesuch";

ok t_cmp($rc, 404, "CAN-2003-0542 test case");

