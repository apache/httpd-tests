use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#test output of some other modules
my %urls = (
    mod_php4      => '/php/var3u.php',
    mod_cgi       => '/modules/cgi/perl_echo.pl',
    mod_echo_post => '/echo_post',
);

my @filter = ('X-AddInputFilter' => 'CaseFilterIn'); #mod_client_add_filter

my %modules = map { $_, Apache::Test::have_module($_) } keys %urls;

my $tests = 1 + grep { $modules{$_} } keys %urls;

plan tests => $tests, test_module 'case_filter_in';

ok 1;

my $data = "v1=one&v3=two&v2=three";

for my $module (sort keys %urls) {
    if ($modules{$module}) {
        verify(POST $urls{$module}, @filter, content => $data);
    }
}

sub verify {
    my $r = shift;
    my $body = $r->content;

    ok $r->code == 200 and $body
      and $body =~ /[A-Z]/ and $body !~ /[a-z]/;
}
