#!/usr/bin/env perl

use Env;

my $query = $ENV{QUERY_STRING};

if ($query) {
    $query =~ /count=([0-9]+)/;
    my $count = $1;
    $query =~ /text=([^&]+)/;
    my $text = $1;
    
    print "Status: 200\n";
    print "Content-Type: text/plain\n";
    print "\n";
    foreach my $i (1..$count) {
        print $text;
    }
}
else {
    print "Status: 400 Parameter Missing\n";
    print "Content-Type: text/plain\n";
    print "\n";
    print <<EOF;
<html><body>
<p>No query was specified.</p>
</body></html>
EOF
}
