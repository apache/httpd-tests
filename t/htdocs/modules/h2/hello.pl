#!/usr/bin/env perl

use Env;

print "Content-Type: text/html\n";
print "\n";

my $ssl_protocol = $ENV{'SSL_PROTOCOL'};
print <<EOF;
<html><body>
<h2>Hello World!</h2>
SSL_PROTOCOL="$ssl_protocol"
</body></html>
EOF