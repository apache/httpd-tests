use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

Apache::TestRequest::user_agent(keep_alive => 1);

my $iters = 10;
my $tests = 3 + $iters * 2;

plan tests => $tests, need need_module('ext_filter');

if (Apache::TestConfig::WINFU()) {
    skip "Unix-only test" foreach 1..$tests;
}

ok t_cmp(GET_BODY("/apache/extfilter/out-foo/foobar.html"), "barbar", "sed output filter");

my $r = POST "/apache/extfilter/in-foo/modules/cgi/perl_echo.pl", content => "foobar";

ok t_cmp($r->code, 200, "echo worked");
ok t_cmp($r->content, "barbar", "request body filtered");

# PR 60375 -- appears to be intermittent failure with 2.4.x ... but works with trunk?
foreach (1..$iters) {
    $r = POST "/apache/extfilter/out-limit/modules/cgi/perl_echo.pl", content => "foo and bar";
    
    ok t_cmp($r->code, 413, "got 413 error");
    ok t_cmp($r->content, qr/413 Request Entity Too Large/, "got 413 error body");
}
