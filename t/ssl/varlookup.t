use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

Apache::TestRequest::scheme('https');

my $url = '/test_ssl_var_lookup';

my $dn =
  "/C=US/ST=California/L=San Francisco" .
  "/O=ASF/OU=httpd-test/CN=client_ok";

my %lookup = (
     HTTP_USER_AGENT => "libwww-perl/$LWP::VERSION",
     HTTP_HOST       => Apache::TestRequest::hostport(),
     REQUEST_SCHEME  => Apache::TestRequest::scheme(),
     SSL_CLIENT_S_DN => $dn,
     NADA            => 'NULL',
);

plan tests => scalar keys %lookup;

for my $key (sort keys %lookup) {
    verify($key);
}

sub verify {
    my $key = shift;
    my $str = GET_BODY("$url?$key", cert => 'client_ok');
    ok $str eq $lookup{$key};
}
