use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#1k..9k, 10k..50k, 100k, 300k, 500k, 2Mb, 4Mb, 6Mb, 10Mb
my @sizes = (1..9, 10..50, 100, 300, 500, 2000, 4000, 6000, 10_000);
my @buff_sizes = (1024, 8192);

plan tests => @sizes * @buff_sizes, [qw(test_rwrite LWP)];

my $location = "/test_rwrite";

for my $buff_size (@buff_sizes) {
    for my $size (@sizes) {
        my $length = $size * 1024;

        print "getting $length bytes of data\n";

        my $str = GET_BODY "$location?$length";

        printf "read %d bytes of data\n", length $str;

        my $chunk = 'a' x 1024;
        ok $str =~ /^($chunk){$size}$/;
    }
}

