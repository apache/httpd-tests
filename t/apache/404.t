use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2;

my $four_oh_four = GET_STR "/404/not/found/test";

print "$four_oh_four\n";

ok ($four_oh_four =~ /HTTP\/1\.[01] 404 Not Found/);
ok ($four_oh_four =~ /Content-Type: text\/html/);
