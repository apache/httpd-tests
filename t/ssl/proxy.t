use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestCommon ();

my %frontend = (
    proxy_http_https  => 'http',
    proxy_https_https => 'https',
    proxy_https_http  => 'https',
);
my %backend = (
    proxy_http_https  => 'https',
    proxy_https_https => 'https',
    proxy_https_http  => 'http',
);

my $num_modules = scalar keys %frontend;
my $post_module = 'eat_post';

my $post_tests = have_module($post_module) ?
  Apache::TestCommon::run_post_test_sizes() : 0;

my $num_http_backends = 0;
for my $module (sort keys %backend) {
    if ($backend{$module} eq "http") {
        $num_http_backends++;
    }
}

plan tests => (8 + $post_tests) * $num_modules - 5 * $num_http_backends,
              [qw(mod_proxy proxy_http.c)];

for my $module (sort keys %frontend) {

    my $scheme = $frontend{$module};
    Apache::TestRequest::module($module);
    Apache::TestRequest::scheme($scheme);

    my $hostport = Apache::TestRequest::hostport();
    my $res;
    my %vars;

    sok {
        t_cmp(200,
              GET('/')->code,
              "/ with $module ($scheme)");
    };

    sok {
        t_cmp(200, 
              GET('/modules/cgi/nph-foldhdr.pl')->code,
              "CGI script with folded headers");
    };

    if ($backend{$module} eq "https") {
        sok {
            t_cmp(200,
                  GET('/verify')->code,
                  "using valid proxyssl client cert");
        };

        sok {
            t_cmp(403,
                  GET('/require/snakeoil')->code,
                  "using invalid proxyssl client cert");
        };

        $res = GET('/require-ssl-cgi/env.pl');

        sok {
            t_cmp(200, $res->code, "protected cgi script");
        };

        my $body = $res->content || "";

        for my $line (split /\s*\r?\n/, $body) {
            my($key, $val) = split /\s*=\s*/, $line, 2;
            next unless $key;
            $vars{$key} = $val || "";
        }

        sok {
            t_cmp($hostport,
                  $vars{HTTP_X_FORWARDED_HOST},
                  "X-Forwarded-Host header");
        };

        sok {
            t_cmp('client_ok',
                  $vars{SSL_CLIENT_S_DN_CN},
                  "client subject common name");
        };
    }

    sok {
        #test that ProxyPassReverse rewrote the Location header
        #to use the frontend server rather than downstream server
        my $uri = '/modules';
        my $ruri = Apache::TestRequest::resolve_url($uri) . '/';

        #tell lwp not to follow redirect so we can see the Location header
        local $Apache::TestRequest::RedirectOK = 0;

        $res = GET($uri);

        my $location = $res->header('Location') || 'NONE';

        t_cmp($ruri, $location, 'ProxyPassReverse Location rewrite');
    };

    Apache::TestCommon::run_post_test($post_module) if $post_tests;
    Apache::TestRequest::user_agent(reset => 1);
}
