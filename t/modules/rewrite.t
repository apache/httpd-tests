use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

## mod_rewrite tests
##
## extra.conf.in:

my @map = qw(txt rnd); #dbm XXX: howto determine dbm support is available?
my @num = qw(1 2 3 4 5 6);
my @url = qw(forbidden gone perm temp);
my $r;

plan tests => @map * @num + 5, need_module 'rewrite';

foreach (@map) {
    foreach my $n (@num) {
        ## throw $_ into upper case just so we can test out internal
        ## 'tolower' map in mod_rewrite
        $_=uc($_);

        $r = GET_BODY("/modules/rewrite/$n", 'Accept' => $_);
        chomp $r;
	$r =~ s/\r//g;

        if ($_ eq 'RND') {
            ## check that $r is just a single digit.
            unless ($r =~ /^[\d]$/) {
                ok 0;
                next;
            }

            ok ($r =~ /^[$r-6]$/);
        } else {
            ok ($r eq $n);
        }
    }
}

$r = GET_BODY("/modules/rewrite/", 'Accept' => 7);
chomp $r;
$r =~ s/\r//g;
ok ($r eq "BIG");
$r = GET_BODY("/modules/rewrite/", 'Accept' => 0);
chomp $r;
$r =~ s/\r//g;
ok ($r eq "ZERO");
$r = GET_BODY("/modules/rewrite/", 'Accept' => 'lucky13');
chomp $r;
$r =~ s/\r//g;
ok ($r eq "JACKPOT");

if (have_module('mod_proxy')) {
    $r = GET_BODY("/modules/rewrite/proxy.html");
    chomp $r;
    ok t_cmp($r, "JACKPOT", "request was proxied");
} else {
    skip "Skipping rewrite to proxy; no proxy module.";
}

if (have_module('mod_proxy') && have_module('mod_cgi')) {
    # regression in 1.3.32 and 2.0.53: (see PR 14518)
    $r = GET_BODY("/modules/rewrite/proxy2/env.pl?fish=fowl");
    chomp $r;
    ok t_cmp($r, qr/QUERY_STRING = fish=fowl\n/s, "QUERY_STRING passed OK");
} else {
    skip "Skipping rewrite QUERY_STRING test; missing proxy or CGI module";
}
