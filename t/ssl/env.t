use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

my %server_expect = (
    SSL_SERVER_I_DN_C => 'US',
    SSL_SERVER_I_DN_CN => 'localhost',
    SSL_SERVER_I_DN_L => 'San Francisco',
    SSL_SERVER_I_DN_O => 'httpd-test',
    SSL_SERVER_I_DN_ST => 'California',
);

my %client_expect = (
    SSL_CLIENT_S_DN_C => 'AU',
    SSL_CLIENT_S_DN_CN => 'localhost',
    SSL_CLIENT_S_DN_L => 'Mackay',
    SSL_CLIENT_S_DN_O => 'Snake Oil, Ltd.',
    SSL_CLIENT_S_DN_OU => 'Staff',
    SSL_CLIENT_S_DN_ST => 'Queensland',
);

my $url = '/ssl-cgi/env.pl';

my $tests = (keys(%server_expect) + keys(%client_expect)) * 2;
plan tests => $tests, test_module 'cgi';

Apache::TestRequest::scheme('https');

my $env = getenv(GET_STR($url));

verify($env, \%server_expect);
verify($env, \%client_expect, 1);

$url = '/require-ssl-cgi/env.pl';

$env = getenv(GET_STR($url, cert => 'client_snakeoil'));

verify($env, \%server_expect);
verify($env, \%client_expect);

sub verify {
    my($env, $expect, $ne) = @_;

    while (my($key, $val) = each %$expect) {
        ok $ne ? not exists $env->{$key} : $env->{$key} eq $val;
    }

}

sub getenv {
    my $str = shift;

    my %env;

    for my $line (split /\n/, $str) {
        my($key, $val) = split /\s*=\s*/, $line, 2;
        next unless $key and $val;
        $env{$key} = $val;
    }

    \%env;
}
