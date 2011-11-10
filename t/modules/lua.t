use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

Apache::TestRequest::module('mod_lua');
my $config = Apache::Test::config();
my $server = $config->server;
my $version = $server->{version};

my $r = GET("/modules/lua/test_hello");

my @ts = (
    { url => "/modules/lua/test_hello", code => 200, rcontent => "Hello Lua World!\n", 
      ctype => "text/plain" },
    { url => "/modules/lua/translate-me", code => 200, 
      rcontent => "Hello Lua World!\n" },
    { url => "/modules/lua/test_version", code => 200, 
      rcontent => qr(^$version) },
);

plan tests => 3 * scalar @ts, need 'lua';

for my $t (@ts) {
    my $url = $t->{"url"};
    my $r = GET $url;
    
    ok t_cmp($r->code, $t->{"code"}, "code for $url");
    ok t_cmp($r->content, $t->{"rcontent"}, "response content for $url");
    if ($t->{"ctype"}) {
        ok t_cmp($r->header("Content-Type"), $t->{"ctype"}, "c-type for $url");
    }
    else {
        skip 1;
    }
}
