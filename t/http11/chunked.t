use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

Apache::TestRequest::user_agent(keep_alive => 1);

Apache::TestRequest::scheme('http')
  unless have_module 'LWP::Protocol::https10'; #lwp 5.60

#chunked encoding is optional and will only be used if
#response is > 4*AP_MIN_BYTES_TO_WRITE (see server/protocol.c)

my @small_sizes = (100, 5000);
my @chunk_sizes = (25432, 75962, 100_000, 300_000);

my $tests = (@chunk_sizes + @small_sizes) * 5;

plan tests => $tests, have_module 'random_chunk';

my $location = '/random_chunk';
my $requests = 0;

for my $size (@chunk_sizes) {
    sok sub {
        my $res = GET "/random_chunk?0,$size";
        my $body = $res->content;
        my $length = 0;

        if ($body =~ s/__END__:(\d+)$//) {
            $length = $1;
        }

        ok $res->protocol eq 'HTTP/1.1';

        my $enc = $res->header('Transfer-Encoding') || '';
        ok $enc eq 'chunked';
        ok ! $res->header('Content-Length');

        ok length($body) == $length;

        $requests++;
        my $request_num = $res->header('Client-Request-Num');

        return $request_num == $requests;
    }, 5;
}

for my $size (@small_sizes) {
    sok sub {
        my $res = GET "/random_chunk?0,$size";
        my $body = $res->content;
        my $content_length = length $res->content;
        my $length = 0;

        if ($body =~ s/__END__:(\d+)$//) {
            $length = $1;
        }

        ok $res->protocol eq 'HTTP/1.1';

        my $enc = $res->header('Transfer-Encoding') || '';
        my $ct  = $res->header('Content-Length') || 0;

        ok $enc ne 'chunked';
        ok $ct == $content_length;

        ok length($body) == $length;

        $requests++;
        my $request_num = $res->header('Client-Request-Num');

        return $request_num == $requests;
    }, 5;
}

