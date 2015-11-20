#!/usr/bin/env perl
use Socket;
use strict;

my $socket_path = '/tmp/test-ptf.sock';
unlink($socket_path);
my $sock_addr = sockaddr_un($socket_path);
socket(my $server, PF_UNIX, SOCK_STREAM, 0) || die "socket: $!";
bind($server, $sock_addr) || die "bind: $!"; 
listen($server,1024) || die "listen: $!";
if (accept(my $new_sock, $server)) {
    my $data = <$new_sock>;
	print $new_sock "HTTP/1.0 200 OK\r\n";
	print $new_sock "Content-Type: text/html\r\n\r\n";
	print $new_sock "<html><body><h1>Hello World</h1><pre>$data</pre></body></html>\n";
	close $new_sock;
}
unlink($socket_path);
