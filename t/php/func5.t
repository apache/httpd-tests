use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig;
use ExtModules::TestEnv;

plan tests => 2, \&ExtModules::TestEnv::has_php4;

my $env = Apache::TestConfig->thaw;

my $expected = <<EXPECT;
foo() will be called on shutdown...
EXPECT

my $result = GET_BODY "/php/func5.php";
ok $result eq $expected;

## open error_log and verify the last line is:
## foo() has been called.
##
## this is kind of lame and may not work...i dont know how php is
## SUPPPOSED to work in this situation...

my $error_log = $env->{httpd_defines}->{DEFAULT_ERRORLOG};
open(ERROR_LOG, $error_log);
my @log = <ERROR_LOG>;
$result = pop @log;
close(ERROR_LOG);
$expected = "foo() has been called.\n";
ok $result eq $expected;
