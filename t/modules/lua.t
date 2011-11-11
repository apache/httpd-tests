use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

my $config = Apache::Test::config();
my $server = $config->server;
my $version = $server->{version};
my $scheme = Apache::Test::vars()->{scheme};

my $https = "nope";
$https = "yep" if $scheme eq "https";

my $pfx = "/modules/lua";

my @ts = (
    { url => "$pfx/hello.lua", rcontent => "Hello Lua World!\n", 
      ctype => "text/plain" },
    { url => "$pfx/translate-me", rcontent => "Hello Lua World!\n" },
    { url => "$pfx/version.lua", rcontent => qr(^$version) },
    { url => "$pfx/method.lua", rcontent => "GET" },
    { url => "$pfx/201.lua", rcontent => "", code => 201 },
    { url => "$pfx/https.lua", rcontent => $https },
);

plan tests => 3 * scalar @ts, need 'lua';

for my $t (@ts) {
    my $url = $t->{"url"};
    my $r = GET $url;
    my $code = $t->{"code"} || 200;

    ok t_cmp($r->code, $code, "code for $url");
    ok t_cmp($r->content, $t->{"rcontent"}, "response content for $url");
    if ($t->{"ctype"}) {
        ok t_cmp($r->header("Content-Type"), $t->{"ctype"}, "c-type for $url");
    }
    else {
        skip 1;
    }
}
