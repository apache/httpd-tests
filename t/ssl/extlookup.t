use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2, need 'test_ssl', need_min_apache_version(2.1);

Apache::TestRequest::scheme("https");

my $oid = "2.16.840.1.113730.1.13"; # Netscape certificate comment

my $r = GET("/test_ssl_ext_lookup?$oid", cert => 'client_ok');

ok t_cmp($r->code, 200, "ssl_ext_lookup works");

my $c = $r->content;

chomp $c;

ok t_cmp($c, "This Is A Comment", "Retrieve nsComment extension");

