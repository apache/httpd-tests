use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my @server_deflate_uris=("/modules/deflate/index.html",
                         "/modules/deflate/apache_pb.gif",
                         "/modules/deflate/asf_logo_wide.jpg",
                        );
my $server_inflate_uri="/modules/deflate/echo_post";

my $tests = @server_deflate_uris;
my $vars = Apache::Test::vars();
my $module = 'default';

plan tests => $tests, have_module 'deflate';

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
