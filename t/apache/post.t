use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

my $times = 5;

plan tests => 2 * $times, [qw(echo_post LWP)];

my $location = "/echo_post";
my $str;
my $value = 'a' x 10;

for (1..$times) {
    my $length = length $value;

    print "posting $length bytes of data\n";

    $str = POST_BODY $location, content => $value;

    ok $str eq $value;

    printf "read %d bytes of POST data\n", length $str;

    $str = POST_BODY "$location?length", content => $value;

    my $expect = join ':', length($value), $value;
    ok $str eq $expect;

    $value .= $value x 10;
}

