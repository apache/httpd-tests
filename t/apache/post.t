use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#1k..9k, 10k..50k, 100k, 300k, 500k, 2Mb, 4Mb, 6Mb, 10Mb
my @sizes = (1..9, 10..50, 100); #300, 500, 2000, 4000, 6000, 10_000);
                                 #XXX: ssl currently falls over here
plan tests => scalar @sizes, [qw(echo_post LWP)];

my $location = "/echo_post";

for my $size (@sizes) {
    my $value = 'a' x ($size * 1024);
    my $length = length $value;

    print "posting $length bytes of data\n";

    my $str = POST_BODY $location, content => $value;

    ok $str eq $value;

    printf "read %d bytes of POST data\n", length $str;
}

