use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2, need [qw(cgi include deflate)];
my $inflator = "/modules/deflate/echo_post";

my @deflate_headers;
push @deflate_headers, "Accept-Encoding" => "gzip";

my @inflate_headers;
push @inflate_headers, "Content-Encoding" => "gzip";

my $uri = "/modules/deflate/ssi/ssi.shtml";

my $content = GET_BODY($uri);

my $expected = "begin-foobar-end\n";

ok t_cmp($content, $expected);

$content = GET_BODY($uri, @deflate_headers);

my $deflated = POST_BODY($inflator, @inflate_headers,
                         content => $content);

ok t_cmp($deflated, $expected);


