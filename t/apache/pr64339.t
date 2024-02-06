
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my @testcases = (
    ['/doc.notml', "application/notreallyxml"],
    ['/doc.xml', "application/xml;charset=utf-8"],
    ['/doc.foo', "application/foo+xml;charset=utf-8"],
    ['/doc.html', "text/html;charset=utf-8"],
);

if (not have_min_apache_version('2.5.2')) {
    print "1..0 # skip: Test valid for 2.5.x only";
    exit 0;
}

plan tests => (2*scalar @testcases), need [qw(xml2enc alias proxy_html proxy)];

foreach my $t (@testcases) {
    my $r = GET("/modules/xml2enc/front".$t->[0]);
    
    ok t_cmp($r->code, 200, "fetching ".$t->[0]);
    ok t_cmp($r->header('Content-Type'), $t->[1], "content-type header test for ".$t->[0]);
}
