use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

##
## mod_env tests
##
## as of 6/21/01, apache bug #7528 is the reason why the UnsetEnv tests fail.
## UnsetEnv does not work at the server level of apache config.
## to make these tests pass, put the UnsetEnv directives in a Files block:
## <Files *>
##     UnsetEnv FOO
## </Files>
##
## the tests will pass.  i've left it with the tests failing because it is
## a legitimate bug, so when the bug is fixed, these tests should pass.
## -jsachs@covalent.net
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
