use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 4, 
    need 'ssl', need_module('actions'),
    need_min_apache_version('2.2.7');

Apache::TestRequest::user_agent( ssl_opts => { SSL_cipher_list => 'ALL', SSL_version => 'TLSv12'});
Apache::TestRequest::user_agent_keepalive(1);
Apache::TestRequest::scheme('https');

my $r;

# Variation of the PR 12355 test which breaks per PR 43738.

$r = POST "/modules/ssl/aes128/empty.pfa", content => "hello world";

ok t_cmp($r->code, 200, "renegotiation on POST works");
ok t_cmp($r->content, "/modules/ssl/aes128/empty.pfa\nhello world", "request body matches response");

$r = POST "/modules/ssl/aes256/empty.pfa", content => "hello world";

ok t_cmp($r->code, 200, "renegotiation on POST works");
ok t_cmp($r->content, "/modules/ssl/aes256/empty.pfa\nhello world", "request body matches response");
