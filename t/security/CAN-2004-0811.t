use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 8, need_apache(2);

my $rc;

foreach my $y (1..4) {
    $rc = GET_RC("/security/CAN-2004-0811/sub/");
    ok t_cmp($rc, 200, "subdir access allowed");
}

foreach my $z (1..4) {
    $rc = GET_RC("/security/CAN-2004-0811/");
    ok t_cmp($rc, 401, "topdir access denied");
}
    
