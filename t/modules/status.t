use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

##
## mod_status quick test
##

plan tests => 1, have_module 'status';

my $uri = '/server-status';
my $servername = Apache::Test::vars()->{servername};

my $html_head =<<HTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html><head>
<title>Apache Status</title>
</head><body>
<h1>Apache Server Status for $servername</h1>
HTML

my $status = GET_BODY $uri;
print "$status\n";
ok ($status =~ /^$html_head/);
