use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 6, ['mod_proxy'];

Apache::TestRequest::module('proxyssl');

my $hostport = Apache::TestRequest::hostport();

ok t_cmp(200,
         GET('/')->code,
         "/ with proxyssl");

ok t_cmp(200,
         GET('/verify')->code,
         "using valid proxyssl client cert");

ok t_cmp(403,
         GET('/require/snakeoil')->code,
         "using invalid proxyssl client cert");

my $res = GET('/require-ssl-cgi/env.pl');

ok t_cmp(200, $res->code, "protected cgi script");

my $body = $res->content || "";

my %vars;
for my $line (split /\s*\r?\n/, $body) {
    my($key, $val) = split /\s*=\s*/, $line, 2;
    next unless $key;
    $vars{$key} = $val || "";
}

ok t_cmp($hostport,
         $vars{HTTP_X_FORWARDED_HOST},
         "X-Forwarded-Host header");

ok t_cmp('client_ok',
         $vars{SSL_CLIENT_S_DN_CN},
         "client subject common name");
