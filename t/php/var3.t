use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, have_module 'php4';

## var3.php source:
## <?php echo "$v1 $v2 $v3"?>
##
## result should be variables v1, v2 and v3.

my $page = '/php/var3.php';
my $v1 = "blah1+blah2+FOO";
my $v2 = "this+is+v2";
my $v3 = "DOOM-GL00m";
my $data = "v1=$v1\&v2=$v2\&v3=$v3";
my $expected = "$v1 $v2 $v3";
$expected =~ s/\+/ /g;

## POST
my $return = POST_BODY $page, content => $data;
ok $return eq $expected;

## GET
$return = GET_BODY "$page?$data";
ok $return eq $expected;
