use strict;
use warnings FATAL => 'all';

use Apache::Test;

#skip all tests in this directory unless php4 module is enabled
plan tests => 1, have_module 'php4';

ok 1;
