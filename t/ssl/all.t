use strict;
use warnings FATAL => 'all';

use Apache::Test;

#skip all tests in this directory unless ssl is enabled
#and LWP has https support
plan tests => 1, [qw(ssl LWP::Protocol::https)];

ok 1;

