use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig;

plan tests => 2, test_module 'php4';

my $env = Apache::TestConfig->thaw;

my $expected = <<EXPECT;
foo() will be called on shutdown...
EXPECT

my $error_log = "$env->{vars}->{t_logs}/error_log";
open(ERROR_LOG, $error_log);
seek(ERROR_LOG, 0, 1); #goto end

my $result = GET_BODY "/php/func5.php";
ok $result eq $expected;

## open error_log and verify the last line is:
## foo() has been called.

$expected = "foo() has been called.\n";

while (<ERROR_LOG>) {
    if ($_ eq $expected) {
        $result = $_;
        last;
    }
}

close(ERROR_LOG);

ok $result eq $expected;


