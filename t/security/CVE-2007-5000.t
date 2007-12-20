use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $vars = Apache::Test::vars();

plan tests => 2, need_imagemap;

my $url = '/security/CVE-2005-3352.map/<foo>';

my $r = GET $url;

ok t_cmp($r->code, 200, "response code is OK");

ok !t_cmp($r->content, qr/<foo>/, "URI was escaped in response");
