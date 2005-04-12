use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my @server_deflate_uris=("/modules/deflate/index.html",
                         "/modules/deflate/apache_pb.gif",
                         "/modules/deflate/asf_logo_wide.jpg",
                         "/modules/deflate/zero.txt",
                        );
my $server_inflate_uri="/modules/deflate/echo_post";

my $cgi_tests = 3;
my $tests = @server_deflate_uris + $cgi_tests;
my $vars = Apache::Test::vars();
my $module = 'default';

plan tests => $tests, need 'deflate', 'echo_post';

print "testing $module\n";

my @deflate_headers;
push @deflate_headers, "Accept-Encoding" => "gzip";

my @inflate_headers;
push @inflate_headers, "Content-Encoding" => "gzip";

for my $server_deflate_uri (@server_deflate_uris) {
    my $original_str = GET_BODY($server_deflate_uri);

    my $deflated_str = GET_BODY($server_deflate_uri, @deflate_headers);

    my $inflated_str = POST_BODY($server_inflate_uri, @inflate_headers,
                                 content => $deflated_str);

    ok $original_str eq $inflated_str;
}

# mod_deflate fixes still pending to make this work...
if (have_module('cgi') && have_min_apache_version('2.1.0')) {
    my $sock = Apache::TestRequest::vhost_socket('default');

    ok $sock;

    Apache::TestRequest::socket_trace($sock);

    $sock->print("GET /modules/cgi/not-modified.pl HTTP/1.0\r\n");
    $sock->print("Accept-Encoding: gzip\r\n");
    $sock->print("\r\n");

    # Read the status line
    chomp(my $response = Apache::TestRequest::getline($sock) || '');
    $response =~ s/\s$//;

    ok t_cmp($response, qr{HTTP/1\.. 304}, "response was 304");
    
    do {
        chomp($response = Apache::TestRequest::getline($sock) || '');
        $response =~ s/\s$//;
    }
    while ($response ne "");
    
    # now try and read any body: should return 0, EOF.
    my $ret = $sock->read($response, 1024);
    ok t_cmp($ret, 0, "expect EOF after 304 header");
} else {
    skip "skipping 304/deflate tests without mod_cgi and httpd >= 2.1.0" foreach (1..$cgi_tests);
}
