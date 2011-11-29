use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 4, 
    need 'ssl', need_module('actions'),
    need_min_apache_version('2.2.7');

Apache::TestRequest::user_agent_keepalive(1);
Apache::TestRequest::scheme('https');

my $r;

# Variation of the PR 12355 test which breaks per PR 43738.

$r = POST "/modules/ssl/md5/empty.pfa", content => "hello world";

ok t_cmp($r->code, 200, "renegotiation on POST works");
ok t_cmp($r->content, "/modules/ssl/md5/empty.pfa\nhello world", "request body matches response");

$r = POST "/modules/ssl/sha/empty.pfa", content => "hello world";

ok t_cmp($r->code, 200, "renegotiation on POST works");
ok t_cmp($r->content, "/modules/ssl/sha/empty.pfa\nhello world", "request body matches response");
