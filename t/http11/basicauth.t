use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#test basic auth with keepalives

Apache::TestRequest::user_agent(keep_alive => 1);

Apache::TestRequest::scheme('http'); #XXX: lwp does not properly support this

plan tests => 3, test_module 'authany';

my $url = '/authany/index.html';

my $res = GET $url;

ok $res->code == 401;

$res = GET $url, username => 'guest', password => 'guest';

ok $res->code == 200;

my $request_num = $res->header('Client-Request-Num');

ok $request_num == 3; #1 => no credentials
                      #2 => 401 response with second request
                      #3 => 200 with guest/guest credentials


