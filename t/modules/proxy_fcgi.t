use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 6,
     need (
        'mod_proxy_fcgi',
        'FCGI',
        'IO::Select',
        need_min_apache_version('2.5.0')
     );

require FCGI;
require IO::Select;

Apache::TestRequest::module("proxy_fcgi");

# Launches a short-lived FCGI daemon that will handle exactly one request with
# the given handler function. Returns the child PID; exits on failure.
sub run_fcgi_handler($$)
{
    my $fcgi_port    = shift;
    my $handler_func = shift;

    # Use a pipe for ready-signalling between the child and parent. Much faster
    # (and more reliable) than just sleeping for a few seconds.
    pipe(READ_END, WRITE_END);
    my $pid = fork();

    unless (defined $pid) {
        t_debug "couldn't fork FCGI process";
        ok 0;
        exit;
    }

    if ($pid == 0) {
        # Child process. Open up a listening socket.
        my $sock = FCGI::OpenSocket(":$fcgi_port", 10);

        # Signal the parent process that we're ready.
        print WRITE_END 'x';
        close WRITE_END;

        # Listen for and respond to exactly one request from the client.
        my $request = FCGI::Request(\*STDIN, \*STDOUT, \*STDERR, \%ENV,
                                    $sock, &FCGI::FAIL_ACCEPT_ON_INTR);

        if ($request->Accept() == 0) {
            # Run the handler.
            $handler_func->();
            $request->Finish();
        }

        # Clean up and exit.
        FCGI::CloseSocket($sock);
        exit;
    }

    # Parent process. Wait for the daemon to launch.
    unless (IO::Select->new((\*READ_END,))->can_read(2)) {
        t_debug "timed out waiting for FCGI process to start";
        ok 0;

        kill 'TERM', $pid;
        # Note that we don't waitpid() here because Perl's fork() implementation
        # on some platforms (Windows) doesn't guarantee that the pseudo-TERM
        # signal will be delivered. Just wait for the child to be cleaned up
        # when we exit.

        exit;
    }

    return $pid;
}

#
# MAIN
#

# XXX There appears to be no way to get the value of a dynamically-reserved
# @NextAvailablePort@ from Apache::Test. We assume here that the port reserved
# for the proxy_fcgi vhost is one greater than the reserved FCGI_PORT, but
# depending on the test conditions, that may not always be the case...
my $fcgi_port = Apache::Test::vars('proxy_fcgi_port') - 1;

# Launch the FCGI process.
my $child = run_fcgi_handler($fcgi_port, sub {
    # Echo all the envvars back to the client.
    print("Content-Type: text/plain\r\n\r\n");
    foreach my $key (sort(keys %ENV)) {
        print($key, "=", $ENV{$key}, "\n");
    }
});

# Hit the backend.
my $r = GET("/fcgisetenv?query");
ok t_cmp($r->code, 200, "proxy to FCGI backend");

# Split the returned envvars into a dictionary.
my %envs = ();

foreach my $line (split /\n/, $r->content) {
    t_debug("> $line"); # log the response lines for debugging

    my @components = split /=/, $line, 2;
    $envs{$components[0]} = $components[1];
}

# Check the response values.
my $docroot = Apache::Test::vars('documentroot');

ok t_cmp($envs{'QUERY_STRING'},     'test_value', "ProxyFCGISetEnvIf can override an existing variable");
ok t_cmp($envs{'TEST_NOT_SET'},     undef,        "ProxyFCGISetEnvIf does not set variables if condition is false");
ok t_cmp($envs{'TEST_EMPTY'},       '',           "ProxyFCGISetEnvIf can set empty values");
ok t_cmp($envs{'TEST_DOCROOT'},     $docroot,     "ProxyFCGISetEnvIf can replace with request variables");
ok t_cmp($envs{'TEST_CGI_VERSION'}, 'v1.1',       "ProxyFCGISetEnvIf can replace with backreferences");

# Rejoin the child FCGI process.
waitpid($child, 0);
