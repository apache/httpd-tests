use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig ();

my $url = '/verify/index.html';

plan tests => 3;

Apache::TestRequest::scheme('https');

my $r;

sok {
    $r = GET $url, cert => undef;
    print $r->as_string;
    $r->code != 200;
};

sok {
    $r = GET $url, cert => 'client_ok';
    print $r->as_string;
    $r->code == 200;
};

sok {
    $r = GET $url, cert => 'client_revoked';
    print $r->as_string;
    $r->code != 200;
};

