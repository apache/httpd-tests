use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = ("0",
                    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                    );
my @req_strings =  ("/echo_post_chunk",
                    "/i_do_not_exist_in_your_wildest_imagination");

# This is expanded out.
# Apache 2.0 handles this test more correctly than Apache 1.3. 
# 1.3 returns 400 Bad Request in this case and it is not worth 
# changing 1.3s behaviour.
my @resp_strings;
if (have_apache(1)) {
   @resp_strings = ("HTTP/1.1 200 OK",
                    "HTTP/1.1 404 Not Found",
                    "HTTP/1.1 400 Bad Request",
                    "HTTP/1.1 400 Bad Request",
		   );
} 
else {
   @resp_strings = ("HTTP/1.1 200 OK",
                    "HTTP/1.1 404 Not Found",
                    "HTTP/1.1 413 Request Entity Too Large",
                    "HTTP/1.1 413 Request Entity Too Large",
                   );
}

my $tests = 4 * @test_strings + 1;
my $vars = Apache::Test::vars();
my $module = 'default';
my $cycle = 0;

plan tests => $tests, ['echo_post_chunk'];

print "testing $module\n";

for my $data (@test_strings) {
  for my $request_uri (@req_strings) {
    my $sock = Apache::TestRequest::vhost_socket($module);
    ok $sock;

    Apache::TestRequest::socket_trace($sock);

    $sock->print("POST $request_uri HTTP/1.0\n");
    $sock->print("Transfer-Encoding: chunked\n");
    $sock->print("\n");
    $sock->print("$data\n");
    $sock->print("X-Chunk-Trailer: $$\n");
    $sock->print("\n");

    #Read the status line
    chomp(my $response = Apache::TestRequest::getline($sock));
    $response =~ s/\s$//;
    ok t_cmp($response, $resp_strings[$cycle++], "response codes");

    do {
        chomp($response = Apache::TestRequest::getline($sock));
        $response =~ s/\s$//;
    }
    while ($response ne "");

    if ($cycle == 1) {
        $response = Apache::TestRequest::getline($sock);
        chomp($response) if (defined($response));
        ok t_cmp($response, "$$", "trailer (pid)");
    }
  }
}
