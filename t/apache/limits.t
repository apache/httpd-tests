#
# Test the LimitRequestLine, LimitRequestFieldSize, LimitRequestFields,
# and LimitRequestBody directives.
#
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#
# These values are chosen to exceed the limits in extra.conf, namely:
#
# LimitRequestLine      128
# LimitRequestFieldSize 1024
# LimitRequestFields    32
# LimitRequestBody      10250000
#

my $fail_requestline = "/" . ('a' x 256);
my $fail_fieldsize   = ('a' x 2048);
my %fail_fieldcount;
my $fail_bodysize    = 'a' x 10260000;

my $res;

#
# Change to '3' when we get the fieldcount test working.
#
plan tests => 2;

$res = GET_RC($fail_requestline);
print "# Testing too-long request line\n",
      "#  Expecting status: 414\n",
      "#  Received status:  $res\n";
ok $res == 414;

$res = GET_RC('/', 'X-overflow-field' => $fail_fieldsize);
print "# Testing too-long request header field\n",
      "#  Expecting status: 400\n",
      "#  Received status:  $res\n";
ok $res == 400;

if (0) {
for (my $i = 1; $i < 65; $i++) {
    $fail_fieldcount{'X-Field$i'} = 'Testing field $i';
}
$res = GET_RC('/', \%fail_fieldcount);
print "# Testing too many request header fields\n",
      "#  Expecting status: 414\n",
      "#  Received status:  $res\n";
ok $res == 414;
}
