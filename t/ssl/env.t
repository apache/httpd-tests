use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();
use Apache::TestSSLCA ();

my $cert = 'client_snakeoil';

my $server_expect =
  Apache::TestSSLCA::dn_vars('cacert', 'SERVER_I');

my $client_expect =
  Apache::TestSSLCA::dn_vars($cert, 'CLIENT_S');

my $url = '/ssl-cgi/env.pl';

my $tests = (keys(%$server_expect) + keys(%$client_expect)) * 2;
plan tests => $tests, \&have_cgi;

Apache::TestRequest::scheme('https');

my $env = getenv(GET_STR($url));

verify($env, $server_expect);
verify($env, $client_expect, 1);

$url = '/require-ssl-cgi/env.pl';

$env = getenv(GET_STR($url, cert => $cert));

verify($env, $server_expect);
verify($env, $client_expect);

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
