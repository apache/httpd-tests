use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, [qw(input_body_filter)];

my $location = '/input_body_filter';

for my $x (1,2) {
    my $data = scalar reverse "ok $x\n";
    print POST_BODY $location, content => $data;
}
