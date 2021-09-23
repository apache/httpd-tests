use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw/t_start_error_log_watch t_finish_error_log_watch/;

my $r;
my $line;
my $count = 0;
my $nb_seconds = 5;

plan tests => 1, need_module('mod_heartbeat', 'mod_heartmonitor');

# Give some time to the heart to beat a few times
t_start_error_log_watch();
sleep($nb_seconds);
my @loglines = t_finish_error_log_watch();

# Heartbeat sent by mod_heartbeat and received by mod_heartmonitor are logged with DEBUG AH02086 message
foreach $line (@loglines) {
    if ($line =~ "AH02086") {
        $count++;
    }
}

print "Expecting at least " . ($nb_seconds-1) . " heartbeat ; Seen: " . $count . "\n";
ok($count >= $nb_seconds-1);
