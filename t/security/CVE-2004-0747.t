use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1, need_apache(2);

my $rc;

$rc = GET_RC "/security/CAN-2004-0747/";

ok t_cmp($rc, 200, "CAN-2004-0747 ap_resolve_env test case");

