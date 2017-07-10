use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

## 
## mod_remoteip tests
##
Apache::TestRequest::module("remote_ip");
plan tests => 6, need_module 'remoteip', have_min_apache_version('2.4.28');

sub slurp
{
    my $s = shift;
    my $r = "";
    my $b;
    while ($s->read($b, 10000) > 0) {
        $r .= $b;
    }
    return $r;
}

my $sock = Apache::TestRequest::vhost_socket("remote_ip");
ok $sock;

# Test human readable format
my $req = "PROXY TCP4 192.168.192.66 192.168.192.77 1111 2222\r\n";
my $url = "GET /index.html HTTP/1.1\r\nConnection: close\r\n";
$url .= "Host: dummy\r\n\r\n";

$sock->print($req . $url);
$sock->shutdown(1);

my $response_data = slurp($sock);
my $r = HTTP::Response->parse($response_data);
chomp(my $content = $r->content);
ok t_cmp($r->code, 200, "PROXY protocol human readable check");
ok t_cmp($content, "PROXY-OK", "Context check");
$sock->shutdown(2);

$req = "PROXY FOO 192.168.192.66 192.168.192.77 1111 2222\r\n";
$sock = Apache::TestRequest::vhost_socket("remote_ip");
ok $sock;
$sock->print($req . $url);
$sock->shutdown(1);

# In httpd, a bad PROXY format simply results in the connection
# being dropped. So ensure we don't get anything that looks
# like a response
$response_data = slurp($sock);
$r = HTTP::Response->parse($response_data);
chomp($content = $r->content);
ok t_cmp($r->code, undef, "broken PROXY protocol human readable check");
ok t_cmp($content, "", "Context check");
$sock->shutdown(2);

# TODO: test binary format