use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my @testcases = (
    ['/apache/buffer_in/', 'foo'],
    ['/apache/buffer_out/', 'foo'],
    ['/apache/buffer_in_out/', 'foo'],
);

plan tests => scalar @testcases * 4, need 'mod_reflector', 'mod_buffer';

foreach my $t (@testcases) {
    ## Small query ##
    my $r = POST($t->[0], content => $t->[1]);

    # Checking for return code
    ok t_cmp($r->code, 200, "Checking return code is '200'");
    # Checking for content
    ok t_is_equal($r->content, $t->[1]);
    
    ## Big query ##
    # 'foo' is 3 bytes, so 'foo' * 1000000 is ~3M, wich is way over the default 'BufferSize'
    $r = POST($t->[0], content => $t->[1] x 1000000);

    # Checking for return code
    ok t_cmp($r->code, 200, "Checking return code is '200'");
    # Checking for content
    ok t_is_equal($r->content, $t->[1] x 1000000);
}
