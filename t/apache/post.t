use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

my $times = 4;

plan tests => 2 * $times, [qw(echo_post LWP)];

my $location = "/echo_post";
my $str;
my $value = 'a' x 10;

for (1..$times) {
    $value .= $value x 10;
    my @data = (key => $value);
    my %data = @data;

    $str = POST_BODY $location, \@data;

    ok $str eq join('=', @data);

    printf "handled %d bytes of POST data\n", length $str;

    my $data = join '&', map { "$_=$data{$_}" } keys %data;

    $str = POST_BODY "$location?length", content => $data;

    my $expect = join(':', length($data), $data);
    ok $str eq $expect;

#    print "EXPECT: $expect\n";
#    print "STR: $str\n";
}

