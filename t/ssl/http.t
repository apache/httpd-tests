use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

#verify we can send an non-ssl http request to the ssl port
#without dumping core.

my $url = '/index.html';

plan tests => 1;

my $config = Apache::TestRequest::test_config();
my $vars = Apache::TestRequest::vars();
local $vars->{port} = $config->port('mod_ssl');
local $vars->{scheme} = 'http';

my $rurl = Apache::TestRequest::resolve_url($url);
print "GET $rurl\n";

my $res = GET($url);
ok $res->code == 400; #HTTP_BAD_REQUEST


