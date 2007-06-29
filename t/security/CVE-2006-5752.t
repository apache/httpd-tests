use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2, need_module 'status';

my $r;

$r = GET "/server-status";

ok t_cmp($r->code, 200, "server-status gave response");

ok t_cmp($r->header("Content-Type"), qr/charset=/, "response content-type had charset");
