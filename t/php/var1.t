use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, test_module 'php4';

## var1.php source:
## <?php echo $variable?>
##
## result should be variable echoed back.

my $page = '/php/var1.php';
my $data = "blah1+blah2+FOO";
#my @data = (variable => $data);
my $expected = $data;
$expected =~ s/\+/ /g;

## POST
#my $return = POST_BODY $page, \@data;
#print STDERR "\n\n$return\n\n";
#ok $return eq $expected;
my $return = POST_BODY $page, content => "variable=$data";
ok $return eq $expected;

## GET
$return = GET_BODY "$page?variable=$data";
ok $return eq $expected;
