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

unless (have_apache 2) {
    #bug exists in apache 1.3, probably will not get fixed
    delete $test{type};
    delete $test{nothere};
}

plan tests => (keys %test) * 1, test_module('env', 'include');

my ($actual, $expected);
foreach (sort keys %test) {
    $expected = $test{$_};
    sok {
        $actual = GET_BODY "/modules/env/$_.shtml";
        chomp $actual;
        print "$_: EXPECT ->$expected<- ACTUAL ->$actual<-\n";
        return $actual eq $expected;
    };
}
