use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $r;
my $get = "Get";
my $head = "Head";
my $post = "Post";

##
## mod_allowmethods test
##
my @test_cases = (
    [ $get, $get, 200 ],
    [ $head, $get, 200 ],
    [ $post, $get, 405 ],
    [ $get, $head, 200 ],
    [ $head, $head, 200 ],
    [ $post, $head, 405 ],
    [ $get, $post, 405 ],
    [ $head, $post, 405 ],
    [ $post, $post, 200 ],
    [ $get, $post . '/reset', 200 ],
);

plan tests => (scalar @test_cases), have_module 'allowmethods';

foreach my $case (@test_cases) {
    my ($fct, $allowed, $rc) = @{$case};
    
    if ($fct eq $get) {
        $r = GET('/modules/allowmethods/' . $allowed . '/');
    }
    elsif ($fct eq $head) {
        $r = HEAD('/modules/allowmethods/' . $allowed . '/');
    }
    elsif ($fct eq $post) {
        $r = POST('/modules/allowmethods/' . $allowed . '/foo.txt');
    }

    ok t_cmp($r->code, $rc, $fct . " - When " . $allowed . " is allowed.");
}
    
