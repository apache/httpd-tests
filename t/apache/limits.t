#
# Test the LimitRequestLine, LimitRequestFieldSize, LimitRequestFields,
# and LimitRequestBody directives.
#
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#
# These values are chosen to exceed the limits in extra.conf, namely:
#
# LimitRequestLine      128
# LimitRequestFieldSize 1024
# LimitRequestFields    32
# LimitRequestBody      10250000
#

my @conditions = qw(requestline fieldsize fieldcount bodysize);

my %fail_inputs =    ('requestline' => ("/" . ('a' x 256)),
                      'fieldsize'   => ('a' x 2048),
                      'bodysize'    => ('a' x 10260000),
                      'fieldcount'  => 64
                      );
my %succeed_inputs = ('requestline' => '/',
                      'fieldsize'   => 'short value',
                      'bodysize'    => ('a' x 1024),
                      'fieldcount'  => 1
                      );

my $res;

#
# Two tests for each of the conditions, plus two more for the
# chunked version of the body-too-large test.
#
plan tests => (@conditions * 2) + 2;

my $testnum = 1;
foreach my $cond (@conditions) {
    foreach my $goodbad qw(succeed fail) {
        my $param;
        $param = ($goodbad eq 'succeed')
            ? $succeed_inputs{$cond}
            : $fail_inputs{$cond};
        if ($cond eq 'fieldcount') {
            my %fields;
            for (my $i = 1; $i <= $param; $i++) {
                $fields{"X-Field-$i"} = "Testing field $i";
            }
            print "# Testing LimitRequestFields; should $goodbad\n";
            ok t_cmp(($goodbad eq 'fail' ? 400 : 200),
                     GET_RC("/", %fields),
                     "Test #$testnum");
            $testnum++;
        }
        elsif ($cond eq 'bodysize') {
            foreach my $chunked qw(disabled enabled) {
                print "# Testing LimitRequestBodySize; should $goodbad\n";
                set_chunking($chunked eq 'enabled');
                ok t_cmp(($goodbad eq 'succeed' ? 200 : 413),
                         GET_RC('/', content => $param),
                         "Test #$testnum");
                $testnum++;
            }
        }
        elsif ($cond eq 'fieldsize') {
            print "# Testing LimitRequestFieldSize; should $goodbad\n";
            ok t_cmp(($goodbad eq 'fail' ? 400 : 200),
                     GET_RC("/", "X-overflow-field" => $param),
                     "Test #$testnum");
            $testnum++;
        }
        elsif ($cond eq 'requestline') {
            print "# Testing LimitRequestLine; should $goodbad\n";
            ok t_cmp(($goodbad eq 'fail' ? 414 : 200),
                     GET_RC($param),
                     "Test #$testnum");
            $testnum++;
        }
    }
}
exit(0);
# 
# $res = GET_RC($fail_requestline);
# print "# Testing too-long request line\n",
#       "#  Expecting status: 414\n",
#       "#  Received status:  $res\n";
# ok $res == 414;
# 
# $res = GET_RC('/', 'X-overflow-field' => $fail_fieldsize);
# print "# Testing too-long request header field\n",
#       "#  Expecting status: 400\n",
#       "#  Received status:  $res\n";
# ok $res == 400;
# 
# for (my $i = 1; $i < 65; $i++) {
#     $fail_fieldcount{"X-Field$i"} = "Testing field $i";
# }
# $res = GET_RC('/', %fail_fieldcount);
# print "# Testing too many request header fields\n",
#       "#  Expecting status: 400\n",
#       "#  Received status:  $res\n";
# ok $res == 400;
# foreach my $with_chunking (0, 1) {
#     print "# Testing too large a request body\n";
#     set_chunking($with_chunking);
#     $res = GET_RC('/', content => $fail_bodysize);
#     print "#  Expecting status: 400\n",
#           "#  Received status:  $res\n";
#     ok $res == 413;
# }
# 
sub set_chunking {
    my ($setting) = @_;
    $setting = $setting ? 1 : 0;
    print "# Chunked transfer-encoding ",
          ($setting ? "enabled" : "disabled"), "\n";
    Apache::TestRequest::user_agent(keep_alive => ($setting ? 1 : 0));
}

