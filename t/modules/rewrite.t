use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## mod_rewrite tests
##
## extra.conf.in:

my @map = qw(txt rnd dbm prg);
my @num = qw(1 2 3 4 5 6);
my @url = qw(forbidden gone perm temp 313);
my $r;

plan tests => @map * @num + 3;

foreach (@map) {
	foreach my $n (@num) {
		## throw $_ into upper case just so we can test out internal
		## 'tolower' map in mod_rewrite
		$_=uc($_);

		$r = GET_BODY "/modules/rewrite/$n", 'Accept' => $_;
		chomp $r;

		if ($_ eq 'RND') {
			ok ($r =~ /^[$r-6]$/);
		} else {
			ok ($r eq $n);
		}
	}
}

$r = GET_BODY "/modules/rewrite/", 'Accept' => 7;
chomp $r;
ok ($r eq "BIG");
$r = GET_BODY "/modules/rewrite/", 'Accept' => 0;
chomp $r;
ok ($r eq "ZERO");
$r = GET_BODY "/modules/rewrite/", 'Accept' => 'lucky13';
chomp $r;
ok ($r eq "JACKPOT");
