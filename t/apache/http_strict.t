use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use MIME::Base64;
use Data::Dumper;

# possible expected results:
#   0:       any HTTP error
#   1:       any HTTP success
#   200-500: specific HTTP status code
#   undef:   HTTPD should drop connection without error message

my @test_cases = (
    [ "GET / HTTP/1.0\r\n\r\n"                      => 1],
    [ "GET / HTTP/1.0\n\n"                          => 400],
    [ "get / HTTP/1.0\r\n\r\n"                      => 501],
    [ "G ET / HTTP/1.0\r\n\r\n"                     => 400],
    [ "G\0ET / HTTP/1.0\r\n\r\n"                    => 400],
    [ "G/T / HTTP/1.0\r\n\r\n"                      => 400],
    [ "GET /\0 HTTP/1.0\r\n\r\n"                    => 400],
    [ "GET / HTTP/1.0\0\r\n\r\n"                    => 400],
    [ "GET / HTT/1.0\r\n\r\n"                       => 0],
    [ "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n"   => 1],
    [ "GET / HTTP/2.0\r\nHost: localhost\r\n\r\n"   => 1],
    [ "GET / HTTP/1.2\r\nHost: localhost\r\n\r\n"   => 1],
    [ "GET / HTTP/1.11\r\nHost: localhost\r\n\r\n"  => 400],
    [ "GET / HTTP/10.0\r\nHost: localhost\r\n\r\n"  => 400],
    [ "GET / HTTP/1.0  \r\nHost: localhost\r\n\r\n" => 400],
    [ "GET / HTTP/1.0 x\r\nHost: localhost\r\n\r\n" => 400],
    [ "GET / HTTP/\r\nHost: localhost\r\n\r\n"      => 0],
    [ "GET / HTTP/0.9\r\n\r\n"                      => 0],
    [ "GET / HTTP/0.8\r\n\r\n"                      => 0],
    [ "GET /\x01 HTTP/1.0\r\n\r\n"                  => 400],
    [ "GET / HTTP/1.0\r\nFoo: bar\r\n\r\n"          => 1],
    [ "GET / HTTP/1.0\r\nFoo: b\0ar\r\n\r\n"        => 400],
    [ "GET / HTTP/1.0\r\nFoo: b\x01ar\r\n\r\n"      => 400],
    [ "GET / HTTP/1.0\r\nFoo bar\r\n\r\n"           => 400],
    [ "GET / HTTP/1.0\r\n: bar\r\n\r\n"             => 400],
    [ "GET / HTTP/1.0\r\nFoo:bar\r\n\r\n"           => 200],
    [ "GET / HTTP/1.0\r\nFoo :bar\r\n\r\n"          => 400],
    [ "GET / HTTP/1.0\r\n Foo:bar\r\n\r\n"          => 400],
    [ "GET / HTTP/1.0\r\nF\x01o: bar\r\n\r\n"       => 400],
    [ "GET / HTTP/1.0\r\nF\ro: bar\r\n\r\n"         => 400],
    [ "GET / HTTP/1.0\r\nF\to: bar\r\n\r\n"         => 400],
    [ "GET / HTTP/1.0\r\nFo: b\tar\r\n\r\n"         => 200],
    [ "GET / HTTP/1.0\r\nFo: bar\r\r\n\r\n"         => 400],
    [ "GET / HTTP/1.0\r\r"                          => undef],
    [ "GET /#frag HTTP/1.0\r\n"                     => 400],
    [ "GET / HTTP/1.0\r\nHost: localhost\r\n" .
                        "Host: localhost\r\n\r\n"   => 400],
    [ "GET http://017700000001/ HTTP/1.0\r\n\r\n"   => 400],
    [ "GET http://0x7f.1/ HTTP/1.0\r\n\r\n"         => 400],
    [ "GET http://127.0.0.1/ HTTP/1.0\r\n\r\n"      => 200],
    [ "GET http://127.01.0.1/ HTTP/1.0\r\n\r\n"     => 400],
    [ "GET http://%3127.0.0.1/ HTTP/1.0\r\n\r\n"    => 400],
    [ "GET / HTTP/1.0\r\nHost: localhost:80\r\n" .
                        "Host: localhost:80\r\n\r\n"            => 400],
    [ "GET / HTTP/1.0\r\nHost: localhost:80 x\r\n\r\n"          => 400],
    [ "GET http://localhost:80/ HTTP/1.0\r\n\r\n"               => 200],
    [ "GET http://localhost:80x/ HTTP/1.0\r\n\r\n"              => 400],
    [ "GET http://localhost:80:80/ HTTP/1.0\r\n\r\n"            => 400],
    [ "GET http://localhost::80/ HTTP/1.0\r\n\r\n"              => 400],
    [ "GET http://foo\@localhost:80/ HTTP/1.0\r\n\r\n"          => 400],
    [ "GET http://[::1]/ HTTP/1.0\r\n\r\n"                      => 1],
    [ "GET http://[::1:2]/ HTTP/1.0\r\n\r\n"                    => 1],
    [ "GET http://[4712::abcd]/ HTTP/1.0\r\n\r\n"               => 1],
    [ "GET http://[4712::abcd:1]/ HTTP/1.0\r\n\r\n"             => 1],
    [ "GET http://[4712::abcd::]/ HTTP/1.0\r\n\r\n"             => 400],
    [ "GET http://[4712:abcd::]/ HTTP/1.0\r\n\r\n"              => 1],
    [ "GET http://[4712::abcd]:8000/ HTTP/1.0\r\n\r\n"          => 1],
    [ "GET http://4713::abcd:8001/ HTTP/1.0\r\n\r\n"            => 400],
    [ "GET / HTTP/1.0\r\nHost: [::1]\r\n\r\n"                   => 1],
    [ "GET / HTTP/1.0\r\nHost: [::1:2]\r\n\r\n"                 => 1],
    [ "GET / HTTP/1.0\r\nHost: [4711::abcd]\r\n\r\n"            => 1],
    [ "GET / HTTP/1.0\r\nHost: [4711::abcd:1]\r\n\r\n"          => 1],
    [ "GET / HTTP/1.0\r\nHost: [4711:abcd::]\r\n\r\n"           => 1],
    [ "GET / HTTP/1.0\r\nHost: [4711::abcd]:8000\r\n\r\n"       => 1],
    [ "GET / HTTP/1.0\r\nHost: 4714::abcd:8001\r\n\r\n"         => 400],
    [ "GET / HTTP/1.0\r\nHost: abc\xa0\r\n\r\n"                 => 400],
    [ "GET / HTTP/1.0\r\nHost: abc\\foo\r\n\r\n"                => 400],
    [ "GET http://foo/ HTTP/1.0\r\nHost: bar\r\n\r\n"           => 200],
    [ "GET http://foo:81/ HTTP/1.0\r\nHost: bar\r\n\r\n"        => 200],
    [ "GET http://[::1]:81/ HTTP/1.0\r\nHost: bar\r\n\r\n"      => 200],
    [ "GET http://10.0.0.1:81/ HTTP/1.0\r\nHost: bar\r\n\r\n"   => 200],

    #
    # tests for response headers
    #
    # Everything after the leading "R" will be sent encoded
    # to .../send_hdr.pl which will decode it and include it
    # in the response headers.
    [ "R" . "Foo: bar"                  => 200 ],
    [ "R" . "Foo:"                      => 200 ],
    [ "R" . ": bar"                     => 500 ],
    [ "R" . "F\0oo: bar"                => 500 ],
    [ "R" . "F\x01oo: bar"              => 500 ],
    [ "R" . "F\noo: bar"                => 500 ],
    # XXX ap_scan_script_header() eats the \r
    #[ "R" . "F\roo: bar"                => 500 ],
    #[ "R" . "Foo: bar\rBaz: h"          => 500 ],
    [ "R" . "Foo: b\tar"                => 200 ],
    [ "R" . "Foo: b\x01ar"              => 500 ],

);

plan tests => scalar(@test_cases),
#    todo => [25, 26],
     need_min_apache_version('2.4.24');

foreach my $t (@test_cases) {
    my $req = $t->[0];
    my $expect = $t->[1];
    my $decoded;

    if ($req =~ s/^R//) {
        $decoded = $req;
        my $q = encode_base64($decoded);
        chomp $q;
        $req = "GET /apache/http_strict/send_hdr.pl?$q HTTP/1.0\r\n\r\n";
    }


    my $sock = Apache::TestRequest::vhost_socket("http_strict");
    if (!$sock) {
        print "# failed to connect\n";
        ok(0);
        next;
    }
    $sock->print($req);
    $sock->shutdown(1);
    sleep(0.1);
    $req = escape($req);
    print "# SENDING:\n# $req\n";
    print "# DECODED: " . escape($decoded) . "\n" if $decoded;

    my $response_data = "";
    my $buf;
    while ($sock->read($buf, 10000) > 0) {
        $response_data .= $buf;
    }
    my $response = HTTP::Response->parse($response_data);
    if ($decoded) {
        $response_data =~ s/<title>.*/.../s;
        my $out = escape($response_data);
        $out =~ s{\\n}{\\n\n# }g;
        print "# RESPONSE:\n# $out\n";
    }
    if (! defined $response) {
        die "HTTP::Response->parse failed";
    }
    my $rc = $response->code;
    if (! defined $rc) {
        if (! defined $expect) {
            print "# expecting dropped connection and HTTPD dropped connection\n";
            ok(1);
        }
        else {
            print "# expecting $expect, but HTTPD dropped the connection\n";
            ok(0);
        }
    }
    elsif ($expect > 100) {
        print "# expecting $expect, got ", $rc, "\n";
        ok ($response->code == $expect);
    }
    elsif ($expect) {
        print "# expecting success, got ", $rc, "\n";
        ok ($rc >= 200 && $rc < 400);
    }
    else {
        print "# expecting error, got ", $rc, "\n";
        ok ($rc >= 400);
    }
}

sub escape
{
    my $in = shift;
    $in =~ s{\\}{\\\\}g;
    $in =~ s{\r}{\\r}g;
    $in =~ s{\n}{\\n}g;
    $in =~ s{\t}{\\t}g;
    $in =~ s{([\x00-\x1f])}{sprintf("\\x%02x", ord($1))}ge;
    return $in;
}
