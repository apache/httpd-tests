use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

my $times = 5;

plan tests => $times, [qw(test_rwrite LWP)];

my $location = "/test_rwrite";
my $str;
my $value = 'a' x 10;

for (1..$times) {
    my $length = length $value;

    print "getting $length bytes of data\n";

    $str = GET_BODY "$location?$length";

    ok $str eq $value;

    printf "read %d bytes of data\n", length $str;

    $value .= $value x 10;
}

