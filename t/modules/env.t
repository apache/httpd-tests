use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

##
## mod_env tests
##

my %test = (
    'host' => $ENV{HOSTNAME},
    'set' => "mod_env test environment variable",
    'unset' => '(none)',
    'type' => '(none)',
    'nothere' => '(none)'
);

plan tests => (keys %test) * 1, test_module('env', 'include');

my ($actual, $expected);
foreach (keys %test) {
    $expected = $test{$_};
    $actual = GET_BODY "/modules/env/$_.shtml";
    chomp $actual;
    print "$_: EXPECT ->$expected<- ACTUAL ->$actual<-\n";
    ok ($actual eq $expected);
}
