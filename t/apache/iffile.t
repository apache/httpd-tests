use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2,
     need(
         need_module('mod_headers'),
         need_min_apache_version('2.5.0')
     );

my $resp = GET('/apache/iffile/document');
ok t_cmp($resp->code, 200);
ok t_cmp($resp->header('X-Out'), "success1, success2, success3, success4");
