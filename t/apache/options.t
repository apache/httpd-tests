use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

my @urls = qw(/);

plan tests => @urls * 2;

for my $url (@urls) {
    my $res = OPTIONS $url;
    ok $res->code == 200;
    my $allow = $res->header('Allow') || '';
    ok $allow =~ /OPTIONS/;
}
