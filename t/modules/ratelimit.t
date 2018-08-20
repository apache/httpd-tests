use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use MIME::Base64;
use Data::Dumper;
use HTTP::Response;
use Socket;

my @testcases = (
    ['/apache/ratelimit/'           => '200'],
    ['/apache/ratelimit/autoindex/' => '200'],
);

plan tests => scalar @testcases, need
                 need_module('mod_ratelimit'),
                 need_module('mod_autoindex'),
                 need_min_apache_version('2.5.1');

foreach my $t (@testcases) {
    my $r = GET($t->[0]);
    chomp $r;
    ok t_cmp($r->code, $t->[1], "rc was bad");
}

