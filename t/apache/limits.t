#
# Test the LimitRequestLine, LimitRequestFieldSize, LimitRequestFields,
# and LimitRequestBody directives.
#
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use LWP;

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
# chunked version of the body-too-large test IFF we have the
# appropriate level of LWP support.
#
my $subtests = (@conditions * 2);
if ($LWP::VERSION >= 5.60) {
    $subtests += 2;
}
else {
    print "# Chunked upload tests will NOT be performed;\n",
          "# LWP 5.60 or later is required and you only have ",
          "$LWP::VERSION installed.\n";
}
plan tests => $subtests;

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
                     GET_RC("/", %fields, 'X-Subtest' => $testnum),
                     "Test #$testnum");
            $testnum++;
        }
        elsif ($cond eq 'bodysize') {
            #
            # Make sure the last situation is keepalives off..
            #
            my @chunk_settings;
            if ($LWP::VERSION < 5.60) {
                @chunk_settings = (0);
            }
            else {
                @chunk_settings = (qw(1 0));
            }
            foreach my $chunked (@chunk_settings) {
                print "# Testing LimitRequestBodySize; should $goodbad\n";
                set_chunking($chunked);
                #
                # Note that this tests different things depending upon
                # the chunking state.  The content-body will not even
                # be counted if the Content-Length of an unchunked
                # request exceeds the server's limit; it'll just be
                # drained and discarded.
                #
                if ($chunked) {
                    my ($req, $resp, $url);
                    $url = Apache::TestRequest::resolve_url('/');
                    $req = HTTP::Request->new(GET => $url);
                    $req->content_type('text/plain');
                    $req->header('X-Subtest' => $testnum);
                    $req->content(chunk_it($param));
                    $resp = Apache::TestRequest::user_agent->request($req);
                    ok t_cmp(($goodbad eq 'succeed' ? 200 : 413),
                             $resp->code,
                             "Test #$testnum");
                    if (! $resp->is_success) {
                        my $str = $resp->as_string;
                        $str =~ s:\n:\n# :gs;
                        print "# Failure details from server:\n# $str";
                    }
                }
                else {
                    ok t_cmp(($goodbad eq 'succeed' ? 200 : 413),
                             GET_RC('/', content_type => 'text/plain',
                                    content => $param,
                                    'X-Subtest' => $testnum),
                             "Test #$testnum");
                }
                $testnum++;
            }
        }
        elsif ($cond eq 'fieldsize') {
            print "# Testing LimitRequestFieldSize; should $goodbad\n";
            ok t_cmp(($goodbad eq 'fail' ? 400 : 200),
                     GET_RC("/", 'X-Subtest' => $testnum,
                            'X-overflow-field' => $param),
                     "Test #$testnum");
            $testnum++;
        }
        elsif ($cond eq 'requestline') {
            print "# Testing LimitRequestLine; should $goodbad\n";
            ok t_cmp(($goodbad eq 'fail' ? 414 : 200),
                     GET_RC($param, 'X-Subtest' => $testnum),
                     "Test #$testnum");
            $testnum++;
        }
    }
}

sub chunk_it {
    my $str = shift;
    my $delay = shift;

    $delay = 1 unless defined $delay;
    return sub {
        select(undef, undef, undef, $delay) if $delay;
        my $l = length($str);
        return substr($str, 0, ($l > 102400 ? 102400 : $l), "");
    }
}

sub set_chunking {
    my ($setting) = @_;
    $setting = $setting ? 1 : 0;
    print "# Chunked transfer-encoding ",
          ($setting ? "enabled" : "disabled"), "\n";
    Apache::TestRequest::user_agent(keep_alive => ($setting ? 1 : 0));
}
