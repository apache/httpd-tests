use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, test_module 'php4';

my $path = Apache::Test::vars()->{t_logs};
my $file = "$path/func5.php.ran";
unlink $file if -e $file;

my $expected = <<EXPECT;
foo() will be called on shutdown...
EXPECT

my $result = GET_BODY "/php/func5.php?$file";
print "GET /php/func5.php?$file\n";
print "expect:\n$expected\nactual:\n$result\n";
ok $result eq $expected;

sleep 1;
ok -e $file;

# Clean up
unlink $file if -e $file;


