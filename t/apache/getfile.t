use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use File::Basename;

my $vars = Apache::TestRequest::vars();
my $perlpod = $vars->{perlpod};
my @pods;

if (-d $perlpod) {
    @pods = map { basename $_ } <$perlpod/*.pod>;
}
else {
    $perlpod = undef;
}

my %other_files = map {
    ("/getfiles-binary-$_", $vars->{$_})
} qw(httpd perl);

plan tests => @pods + keys(%other_files), sub { $perlpod };

my $location = "/getfiles-perl-pod";

for my $file (@pods) {
    verify(\GET_BODY("$location/$file"), "$perlpod/$file");
}

#XXX: should use lwp callback hook so we dont slurp 5M+ into memory
for my $url (keys %other_files) {
    verify(\GET_BODY($url), $other_files{$url});
}

sub verify {
    my($str, $file) = @_;
    my $slen = length($$str);
    my $flen = -s $file;
    print "downloaded $slen bytes, file is $flen bytes\n";
    ok $slen == $flen;
}
