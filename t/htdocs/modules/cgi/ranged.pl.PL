use strict;

print "Content-type: text/plain\n";

if ($ENV{'Range'} eq 'bytes=5-10/10') {
    print "Content-Range: bytes 5-10/10\n\n";
    print "hello\n";
} else {
    print "\npardon?\n";
}

