use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, ['mod_proxy'];

Apache::TestRequest::module('proxyssl');

ok t_cmp(200,
         GET('/')->code,
         "/ with proxyssl"
        );
