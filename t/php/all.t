use strict;
use warnings FATAL => 'all';

use Apache::Test;

#skip all tests in this directory unless php4 module is enabled
plan tests => 1, need_php;

ok 1;
