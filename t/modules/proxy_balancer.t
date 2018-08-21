use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

plan tests => 3, need 'proxy_balancer', 'proxy_http';

Apache::TestRequest::module("proxy_http_balancer");
Apache::TestRequest::user_agent(requests_redirectable => 0);


my $r = GET("/baltest1/index.html");
ok t_cmp($r->code, 200, "Balancer did not die");

$r = GET("/baltest2/index.html");
ok t_cmp($r->code, 200, "Balancer did not die");

$r = GET("/baltest3/index.html");
ok t_cmp($r->code, 200, "Balancer did not die");

if (have_min_apache_version("2.3.0")) {
    # $r = GET("/baltest4/index.html");
    # ok t_cmp($r->code, 200, "Balancer did not die");
}
