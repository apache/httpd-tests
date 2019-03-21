use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use MIME::Base64;
use Data::Dumper;
use HTTP::Response;
use Socket;

#   undef:   HTTPD should drop connection without error message

my @test_cases = (
    # request, status code global, status code 'mergeslashes off' VH, msg
  [ "GET /authz_core/a/b/c/index.html HTTP/1.1\r\nHost: merge-default\r\n\r\n"    => 403, "exact match"],
  [ "GET //authz_core/a/b/c/index.html HTTP/1.1\r\nHost: merge-default\r\n\r\n"    => 403, "merged even at front"],
  [ "GET ///authz_core/a/b/c/index.html HTTP/1.1\r\nHost: merge-default\r\n\r\n"    => 403, "merged even at front"],
  [ "GET /authz_core/a/b/c//index.html HTTP/1.1\r\nHost: merge-default\r\n\r\n"   => 403, "c// should be merged"],
  [ "GET /authz_core/a//b/c/index.html HTTP/1.1\r\nHost: merge-default\r\n\r\n"   => 403, "a// should be merged"],
  [ "GET /authz_core/a//b/c/index.html HTTP/1.1\r\nHost: merge-disabled\r\n\r\n"  => 403, "a// matches locationmatch"],
  [ "GET /authz_core/a/b/c//index.html HTTP/1.1\r\nHost: merge-disabled\r\n\r\n"  => 200, "c// doesn't match locationmatch"],
);
plan tests => scalar(@test_cases), need_min_apache_version('2.4.39');


  foreach my $t (@test_cases) {
    my $req = $t->[0];
    my $expect = $t->[1];
    my $desc = $t->[2];
    my $decoded;

    my $sock = Apache::TestRequest::vhost_socket("core");
    if (!$sock) {
        print "# failed to connect\n";
        ok(0);
        next;
    }

    $sock->print($req);
    $sock->shutdown(1);
    sleep(0.1);
    $req = escape($req);
    print "# SENDING to " . peer($sock) . "\n# $req\n";

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
        print "# expected $expect, got " . $response->code . " for $desc\n";
        ok ($response->code, $expect, $desc );
    }
    elsif ($expect == 90) {
        print "# expecting headerless HTTP/0.9 body, got response\n";
        ok (1);
    }
    elsif ($expect) {
        print "# expecting success, got ", $rc, ": $desc\n";
        ok ($rc >= 200 && $rc < 400);
    }
    else {
        print "# expecting error, got ", $rc, ": $desc\n";
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

sub peer
{
   my $sock = shift;
   my $hersockaddr    = getpeername($sock);
   my ($port, $iaddr) = sockaddr_in($hersockaddr);
   my $herhostname    = gethostbyaddr($iaddr, AF_INET);
   my $herstraddr     = inet_ntoa($iaddr);
   return "$herstraddr:$port";
}
