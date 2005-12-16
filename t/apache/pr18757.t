#
# Regression test for PR 18757.
#
# Annoyingly awkward to write because LWP is a poor excuse for an HTTP
# interface and will lie about what response headers are sent, so this
# must be yet another test which speaks TCP directly.
#

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2, need 'cgi', 'proxy', need_min_apache_version('2.2.1');

my $sock = Apache::TestRequest::vhost_socket("proxy_http_https");

my $url = Apache::TestRequest::resolve_url("/modules/cgi/empty.pl");

t_debug "URL via proxy is $url";

ok $sock;

$sock->print("HEAD $url HTTP/1.0\r\n");
$sock->print("\r\n");

my $ok = 0;
my $response;

do {
    chomp($response = Apache::TestRequest::getline($sock) || '');
    $response =~ s/\s$//;
    
    if ($response =~ /Content-Length: 0/) {
        $ok = 1;
    }

}
while ($response ne "");

ok t_cmp($ok, 1, "whether proxy strips Content-Length header");
