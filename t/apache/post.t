use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestCommon ();

my $module = 'eat_post';
my $num = Apache::TestCommon::run_post_test_sizes();

plan tests => $num, need need_lwp, need_module($module);

Apache::TestCommon::run_post_test($module);
