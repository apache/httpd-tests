use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

Apache::TestRequest::user_agent(keep_alive => 1);

Apache::TestRequest::scheme('http'); #XXX: lwp does not properly support this

                       #XXX need to spend more time with http11
my @sizes = (100_000); #(100, 5000, 100_000, 300_000);

plan tests => @sizes * 2, test_module 'random_chunk';

my $location = '/random_chunk';

for my $size (@sizes) {
    my $res = GET "/random_chunk?0,$size";
    my $body = $res->content;
    my $length = 0;

    if ($body =~ s/__END__:(\d+)$//) {
        $length = $1;
    }

    ok $res->protocol eq 'HTTP/1.1';
    ok length($body) == $length;
}

