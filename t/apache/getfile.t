use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest ();
use Apache::TestUtil;
use File::Basename;

my $vars = Apache::Test::vars();
my $perlpod = $vars->{perlpod};
my @pods;

if (-d $perlpod) {
    @pods = map { basename $_ } <$perlpod/*.pod>;
}
else {
    $perlpod = undef;
    #XXX: howto plan ..., skip_unless(...) + have_module(...) ?
    push @Apache::Test::SkipReasons,
      "dir $vars->{perlpod} doesn't exist"
}

my %other_files = map {
    ("/getfiles-binary-$_", $vars->{$_})
} qw(httpd perl);

plan tests => @pods + keys(%other_files), 'LWP';

my $location = "/getfiles-perl-pod";
my $ua = Apache::TestRequest::user_agent();

for my $file (@pods) {
    verify("$location/$file", "$perlpod/$file");
}

#XXX: should use lwp callback hook so we dont slurp 5M+ into memory
for my $url (sort keys %other_files) {
    verify($url, $other_files{$url});
}

sub verify {
    my($url, $file) = @_;

    my $flen = -s $file;
    my $received = 0;

    $ua->do_request(GET => $url,
                    sub {
                        my($chunk, $res) = @_;
                        $received += length $chunk;
                    });

    ok t_cmp($flen, $received, "download of $url");
}
