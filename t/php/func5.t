use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig;

plan tests => 2, test_module 'php4';

my $env = Apache::TestConfig->thaw;

my $file = "htdocs/php/func5.php.ran";
unlink $file if -e $file;

my $expected = <<EXPECT;
foo() will be called on shutdown...
EXPECT

my $result = GET_BODY "/php/func5.php";
ok $result eq $expected;
ok -e $file;

# Clean up
unlink $file if -e $file;


