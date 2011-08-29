use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_write_file);

# test content-length header in byterange-requests
# test invalid range headers

my $url = "/apache/chunked/byteranges.txt";
my $file = Apache::Test::vars('serverroot') . "/htdocs$url";

my $content = "";
$content .= sprintf("%04d", $_) for (1 .. 10000);
t_write_file($file, $content);
my $real_clen = length($content);


my @test_cases = ( 1, 2, 10, 50, 100);
my @test_cases2 = ("", ",", "7-1", "foo");
plan tests => scalar(@test_cases) + 2 * scalar(@test_cases2), need need_lwp;

foreach my $num (@test_cases) {
    my @ranges;
    foreach my $i (0 .. ($num-1)) {
        push @ranges, sprintf("%d-%d", $i * 100, $i * 100 + 1);
    }
    my $range = join(",", @ranges);
    my $result = GET $url, "Range" => "bytes=$range";
    print "got ", $result->code, "\n";
    if ($result->code != 206) {
        print "did not get 206\n";
        ok(0);
        next;
    }
    my $clen = $result->header("Content-Length");
    my $body = $result->content;
    my $blen = length($body);
    if ($blen == $real_clen) {
        print "Did get full content, should have gotten only parts\n";
        ok(0);
        next;
    }
    print "body length $blen\n";
    if (defined $clen) {
        print "Content-Length: $clen\n";
        if ($blen != $clen) {
            print "Content-Length does not match body\n";
            ok(0);
            next;
        }
    }
    ok(1);
}

# test invalid range headers, with and without "bytes="
my @test_cases3 = map { "bytes=" . $_ } @test_cases2;
foreach my $range (@test_cases2, @test_cases3) {
    my $result = GET $url, "Range" => "$range";
    my $code = $result->code;
    print "Got $code\n";
    if ($code == 216) {
        # guess that's ok
        ok(1);
    }
    elsif ($code == 206) {
        print "got partial content response with invalid range header\n";
        ok(0);
    }
    elsif ($code == 200) {
        my $body = $result->content;
        if ($body != $content) {
            print "Body did not match expected content\n";
            ok(0);
        }
        ok(1);
    }
    else {
        print "Huh?\n";
        ok(0);
    }
}

