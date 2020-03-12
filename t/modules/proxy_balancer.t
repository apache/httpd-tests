use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

my @echos = ('A'x8, 'A'x64, 'A'x2048, 'A'x4096);

# Fix not in 2.4.42 candidate yet
my $skipbodyfailover = !need_min_apache_version("2.4.43");

plan tests => 3+(2*scalar @echos), need 'proxy_balancer', 'proxy_http';

Apache::TestRequest::module("proxy_http_balancer");
Apache::TestRequest::user_agent(requests_redirectable => 0);

my $r;

if (have_module('lbmethod_byrequests')) {
    $r = GET("/baltest1/index.html");
    ok t_cmp($r->code, 200, "Balancer did not die");
} else {
    skip "skipping tests without mod_lbmethod_byrequests" foreach (1..1);
}

if (have_module('lbmethod_bytraffic')) {
    $r = GET("/baltest2/index.html");
    ok t_cmp($r->code, 200, "Balancer did not die");
} else {
    skip "skipping tests without mod_lbmethod_bytraffic" foreach (1..1);
}

if (have_module('lbmethod_bybusyness')) {
    $r = GET("/baltest3/index.html");
    ok t_cmp($r->code, 200, "Balancer did not die");
} else {
    skip "skipping tests without mod_lbmethod_bybusyness" foreach (1..1);
}

if (have_module('lbmethod_heartbeat')) {
    #$r = GET("/baltest4/index.html");
    #ok t_cmp($r->code, 200, "Balancer did not die");
} else {
    #skip "skipping tests without mod_lbmethod_heartbeat" foreach (1..1);
}



# PR63891
foreach my $t (@echos) {
    $r = POST "/baltest_echo_post", content => $t;
    skip $skipbodyfailover, t_cmp($r->code, 200, "failed over");
    skip $skipbodyfailover, t_cmp($r->content, $t, "response body echoed");
}


