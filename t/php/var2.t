use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, have_module 'php4';

## var2.php source:
## <?php echo "$v1 $v2"?>
##
## result should be variables v1 and v2.

my $page = '/php/var2.php';
my $v1 = "blah1+blah2+FOO";
my $v2 = "this+is+v2";
my $data = "v1=$v1\&v2=$v2";
my $expected = "$v1 $v2";
$expected =~ s/\+/ /g;

## POST
my $return = POST_BODY $page, content => $data;
ok $return eq $expected;

## GET
$return = GET_BODY "$page?$data";
ok $return eq $expected;
