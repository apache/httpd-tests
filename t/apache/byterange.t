use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use File::Basename;

my $ua = Apache::TestRequest::user_agent();

my $vars = Apache::TestRequest::vars();
my $perlpod = $vars->{perlpod};
my @pods;

if (-d $perlpod) {
    @pods = map { basename $_ } <$perlpod/*.pod>;
}
else {
    $perlpod = undef;
}

#too friggin slow over ssl at the moment
#my %other_files = map {
#    ("/getfiles-binary-$_", $vars->{$_})
#} qw(httpd perl);

my %other_files;

plan tests => @pods + keys(%other_files), sub { $perlpod };

for my $url (keys %other_files) {
    verify($url, $other_files{$url});
}

my $location = "/getfiles-perl-pod";

for my $file (@pods) {
    verify("$location/$file", "$perlpod/$file");
}

sub verify {
    my($url, $file) = @_;
    my $debug = $Apache::TestRequest::DebugLWP;

    $url = Apache::TestRequest::resolve_url($url);
    my $req = HTTP::Request->new(GET => $url);

    my $total = 0;
    my $chunk_size = 8192;

    my $wanted = -s $file;

    while ($total < $wanted) {
        my $end = $total + $chunk_size;
        if ($end > $wanted) {
            $end = $wanted;
        }

        my $range = "bytes=$total-$end";
        $req->header(Range => $range);

        print $req->as_string if $debug;

        my $res = $ua->request($req);
        my $content_range = $res->header('Content-Range') || 'NONE';

        $res->content("") if $debug and $debug == 1;
        print $res->as_string if $debug;

        if ($content_range =~ m:^bytes\s+(\d+)-(\d+)/(\d+):) {
            my($start, $end, $total_bytes) = ($1, $2, $3);
            $total += ($end - $start) + 1;
        }
        else {
            print "Range:         $range\n";
            print "Content-Range: $content_range\n";
            last;
        }
    }

    print "downloaded $total bytes, file is $wanted bytes\n";

    ok $total == $wanted;
}
