use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, ['mod_proxy'];

Apache::TestRequest::module('proxyssl');

ok GET_OK('/');
