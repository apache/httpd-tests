use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_RC);

use POSIX qw(strftime);

plan tests => 1, have_module 'php4';

# Test for bug where Apache serves a 304 if the PHP file (on disk) has
# not been modified since the date given in an If-Modified-Since
# header; http://bugs.php.net/bug.php?id=17098

ok t_cmp(
    200,
    GET_RC("/php/hello.php",
        "If-Modified-Since" => strftime("%a, %d %b %Y %T GMT", gmtime)),
    "not 304 if the php file has not been modified since If-Modified-Since"
);

