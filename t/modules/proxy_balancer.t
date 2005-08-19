use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

plan tests => 1, need 'proxy_balancer', 'proxy_http';

Apache::TestRequest::module("proxy_http_balancer");
Apache::TestRequest::user_agent(requests_redirectable => 0);


my $r = GET("/baltest/index.html");
ok t_cmp($r->code, 200, "Balancer did not die");
