use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#test output of some other modules
my %urls = (
    mod_php4        => '/php/hello.php',
    mod_cgi         => '/modules/cgi/perl.pl',
    mod_test_rwrite => '/test_rwrite',
    mod_alias       => '/getfiles-perl-pod/perlsub.pod',
);

my @filter = ('X-AddOutputFilter' => 'CaseFilter'); #mod_client_add_filter

my %modules = map { $_, Apache::Test::have_module($_) } keys %urls;

my $tests = 1 + grep { $modules{$_} } keys %urls;

plan tests => $tests, have_module 'case_filter';

verify(GET '/', @filter);

for my $module (sort keys %urls) {
    if ($modules{$module}) {
        my $r = GET $urls{$module}, @filter;
        print "# testing $module with $urls{$module}\n";
        print "# expected 200\n";
        print "# received ".$r->code."\n";
        verify($r);
    }
}

sub verify {
    my $r = shift;
    my $url = shift;
    my $body = $r->content;

    ok $r->code == 200 and $body
      and $body =~ /[A-Z]/ and $body !~ /[a-z]/;
}
