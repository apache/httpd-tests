use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig;
use File::stat;

## mod_cgi test
##
## extra.conf.in:
## <IfModule mod_cgi.c>
## AddHandler cgi-script .sh
## AddHandler cgi-script .pl
## ScriptLog logs/mod_cgi.log
## ScriptLogLength 8192
## ScriptLogBuffer 256
## <Directory @SERVERROOT@/htdocs/modules/cgi>
## Options +ExecCGI
## </Directory>
## </IfModule>
## 

my @post_content = (10, 99, 250, 255, 256, 257, 258, 1024);

my %test = (
    'perl.pl' => {
        'rc' => 200,
        'expect' => 'perl cgi'
    },
    'bogus-perl.pl' => {
        'rc' => 500,
        'expect' => 'none'
    },
    'sh.sh' => {
        'rc' => 200,
        'expect' => 'sh cgi'
    },
    'bogus-sh.sh' => {
        'rc' => 500,
        'expect' => 'none'
    }
);

plan tests => (keys %test) * 2 + @post_content * 3 + 3, test_module 'cgi';

my ($expected, $actual);
my $path = "/modules/cgi";
my $config = Apache::TestConfig->thaw;
my $cgi_log = "$config->{vars}->{t_logs}/mod_cgi.log";
my ($bogus,$log_size,$stat) = (0,0,0);

unlink $cgi_log if -e $cgi_log;

foreach (keys %test) {
    $expected = $test{$_}{rc};
    $actual = GET_RC "$path/$_";
    ok ($actual eq $expected);

    unless ($test{$_}{expect} eq 'none') {
        $expected = $test{$_}{expect};
        $actual = GET_BODY "$path/$_";
        chomp $actual if $actual =~ /\n$/;
        ok ($actual eq $expected);
    }

    ## verify bogus cgi's get handled correctly
    ## logging to the cgi log
    if ($_ =~ /^bogus/) {
        $bogus++;
        if ($bogus == 1) {

            ## make sure cgi log got created, get size.
            if (-e $cgi_log) {
                ok 1;
                $stat = stat($cgi_log);
                $log_size = $$stat[7];
            } else {
                ok 0;
            }
        } else {

            ## make sure log got bigger.
            if (-e $cgi_log) {
                $stat = stat($cgi_log);
                ok ($$stat[7] > $log_size);
                $log_size = $$stat[7];
            } else {
                ok 0;
            }
        }
    }
}

## post lots of content to a bad cgi, so we can verify
## ScriptLogBuffer is working.
my $content = 0;
foreach my $length (@post_content) {
    $content++;
    $expected = '500';
    $actual = POST_RC "$path/bogus-perl.pl", content => "$content"x$length;
    ## should get rc 500
    ok ($actual eq $expected);

    ## cgi log should be bigger.
    ## as long as it's under ScriptLogLength (8192)
    $stat = stat($cgi_log);
    if ($log_size < 8192) {
        ok ($$stat[7] > $log_size);
    } else {
        ## should not fall in here at this point,
        ## but just in case...
        ok ($$stat[7] eq $log_size);
    }
    $log_size = $$stat[7];

    ## there should be less than ScriptLogBuffer (256)
    ## characters logged from the post content
    open (LOG, $cgi_log);
    my $multiplier = 256;
    while (<LOG>) {
        if (/^$content+$/) {
            chomp;
            $multiplier = $length unless $length > $multiplier;
            ok ($_ eq "$content"x$multiplier);
            last;
        }
    }
    close (LOG);
}

## make sure cgi log does not 
## keep logging after it is bigger
## than ScriptLogLength (8192)
for (my $i=1 ; $i<=8 ; $i++) {

    ## request the 1k bad cgi 8 times
    ## (1k of data logged per request)
    GET_RC "$path/bogus1k.pl";

    ## when log goes over max size stop making requests
    $stat = stat($cgi_log);
    $log_size = $$stat[7];
    last if ($log_size > 8192);

}
## make sure its over (or equal) 8192
ok ($log_size >= 8192);

## make sure it does not grow now.
GET_RC "$path/bogus1k.pl";
$stat = stat($cgi_log);
ok ($log_size eq $$stat[7]);

GET_RC "$path/bogus-perl.pl";
$stat = stat($cgi_log);
ok ($log_size eq $$stat[7]);

## clean up
unlink $cgi_log;
