use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#1k..9k, 10k..50k, 100k, 300k, 500k, 2Mb, 4Mb, 6Mb, 10Mb
my @sizes = (1..9, 10..50, 100, 300, 500, 2000, 4000, 6000, 10_000);

plan tests => scalar @sizes, [qw(test_rwrite LWP)];

my $location = "/test_rwrite";

for my $size (@sizes) {
    my $value = 'a' x ($size * 1024);
    my $length = length $value;

    print "getting $length bytes of data\n";

    my $str = GET_BODY "$location?$length";

    ok $str eq $value;

    printf "read %d bytes of data\n", length $str;
}

