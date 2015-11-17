#!/usr/bin/env perl

use Env;

print "Content-Type: text/html\n";
print "\n";

#my $ssl_protocol = $ENV{'SSL_TLS_SNI'};
print <<EOF
<html><body>
<h2>Hello World!</h2>
</body></html>
EOF
