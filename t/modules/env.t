use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

##
## mod_env tests
##

my %test = (
    'host' => $ENV{APACHE_TEST_HOSTNAME},
    'set' => "mod_env test environment variable",
    'unset' => '(none)',
    'type' => '(none)',
    'nothere' => '(none)'
);

plan tests => (keys %test) * 1, have_module('env', 'include');

my ($actual, $expected);
foreach (sort keys %test) {
    $expected = $test{$_} || 'ERROR EXPECTED UNDEFINED';
    sok {
        $actual = GET_BODY "/modules/env/$_.shtml";
        $actual =~ s/[\r\n]+$//s;
        print "$_: EXPECT ->$expected<- ACTUAL ->$actual<-\n";
        return $actual eq $expected;
    };
}
