use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;

#verify we can send an non-ssl http request to the ssl port
#without dumping core.

my $url = '/index.html';

my @todo;

if (Apache::TestConfig::WIN32) {
    print "\n#ap_core_translate() chokes on ':' here\n",
          "#where r->uri = /mod_ssl:error:HTTP-request\n";
    @todo = (todo => [1]);
}

plan tests => 1, @todo;

my $config = Apache::Test::config();
my $vars = Apache::Test::vars();
local $vars->{port} = $config->port('mod_ssl');
local $vars->{scheme} = 'http';

my $rurl = Apache::TestRequest::resolve_url($url);
print "GET $rurl\n";

my $res = GET($url);
ok $res->code == 400; #HTTP_BAD_REQUEST


