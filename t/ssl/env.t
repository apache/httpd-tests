use strict;
use warnings FATAL => 'all';
use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();
use Apache::TestSSLCA ();

#if keepalives are on, renegotiation not happen again once
#a client cert is presented.
Apache::TestRequest::user_agent_keepalive(0);

my $cert = 'client_snakeoil';

my $server_expect =
  Apache::TestSSLCA::dn_vars('ca', 'SERVER_I');

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
        if (Apache::TestConfig::WIN32) {
            #perl uppercases all %ENV keys
            #which causes SSL_*_DN_Email lookups to fail
            $key = uc $key;
        }
        unless ($ne || $env->{$key}) {
            print "#$key does not exist\n";
            $env->{$key} = ""; #prevent use of unitialized value
        }
        ok $ne ? not exists $env->{$key} : $env->{$key} eq $val;
    }
}

sub getenv {
    my $str = shift;

    my %env;

    for my $line (split /[\r\n]+/, $str) {
        my($key, $val) = split /\s*=\s*/, $line, 2;
        next unless $key and $val;
        $env{$key} = $val;
    }

    \%env;
}
