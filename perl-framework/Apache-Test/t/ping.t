use strict;
use warnings FATAL => 'all';

use Apache::Test;

plan tests => 3;

use Apache::TestConfig ();

my $test_config = Apache::TestConfig->thaw;

ok $test_config;

my $server = $test_config->server;

ok $server;

ok $server->ping;

