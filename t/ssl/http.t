use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

#verify we can send an non-ssl http request to the ssl port
#without dumping core.

my $url = '/index.html';

plan tests => 1;

my $vars = Apache::TestRequest::vars();
local $vars->{port} = $vars->{sslport};
local $vars->{scheme} = 'http';

my $rurl = Apache::TestRequest::resolve_url($url);
print "GET $rurl\n";

my $str = GET_STR($url);
ok $str;
print $str;

