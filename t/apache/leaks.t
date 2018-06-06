use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $url = "/memory_track";
my $init_iters = 2000;
my $iters = 500;

my $num_tests = $init_iters + $iters * 2;
plan tests => $num_tests;

### this doesn't seem sufficient to force all requests over a single
### persistent connection any more, is there a better trick?
Apache::TestRequest::user_agent(keep_alive => 1);
Apache::TestRequest::scheme('http');

my $r = GET $url;

if ($r->code != 200) {
    # these tests will be skipped for async MPMs or with an APR not
    # built with --enable-pool-debug.
    skip "mod_memory_track not activated" foreach (1..$num_tests);
}
else {
    my $cid = -1;
    my $mem;

    # initial iterations should get workers to steady-state memory use.
    foreach (1..$init_iters) {
        ok t_cmp(GET_RC($url), 200, "200 response");
    }

    # now test whether c->pool memory is increasing for further
    # requests on a given conn_rec (matched by id)... could track them
    # all with a bit more effort.
    foreach (1..$iters) {
        $r = GET $url;

        print "# iter $_\n";
        
        ok t_cmp($r->code, 200, "got response");

        my $content = $r->content;
        chomp $content;
        my ($key, $id, $bytes) = split ',', $content;

        print "# $key, $id, $bytes\n";

        if ($cid == -1) {
            $cid = $id;
            $mem = $bytes;
            ok 1;
        }
        elsif ($cid != $id) {
            skip "using wrong connection";
        }
        elsif ($bytes > $mem) {
            print "# error: pool memory increased from $mem to $bytes!\n";
            ok 0;
        }
        else {
            ok 1;
        }
    }
}
    
