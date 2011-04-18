use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp t_write_file);
use File::Spec;

plan tests => 1, need need_cgi, need_module('mod_filter'),
                 need_module('mod_case_filter');

my $r = GET_BODY('/modules/cgi/xother.pl');

ok t_cmp($r, "HELLOWORLD");

