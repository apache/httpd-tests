use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Time::Local;

## mod_expires tests
##
## extra.conf.in:
## 
## <Directory @SERVERROOT@/htdocs/modules/expires>
## ExpiresActive On
## ExpiresDefault "modification plus 10 years 6 months 2 weeks 3 days 12 hours 30 minutes 19 seconds"
## ExpiresByType text/plain M60
## ExpiresByType image/gif A120
## ExpiresByType image/jpeg A86400
## </Directory>
##

my @page = ('index.html', 'text.txt', 'image.gif', 'foo.jpg');
my %exp = (	'default' => 'M332256619',
		'text/plain' => 'M60',
		'image/gif' => 'A120',
		'image/jpeg' => 'A86400');

plan tests => @page * 2;

foreach (@page) {
	my $head = HEAD_STR "/modules/expires/$_";
	ok ($head =~ /^HTTP\/1\.[1|0] 200 OK/);

	my ($access, $expires, $modified, $type);
	foreach my $header (split /\n/, $head) {
		if ($header =~ /^Date: (.*)$/) {
			$access = $1;
		} elsif ($header =~ /^Expires: (.*)$/) {
			$expires = $1;
		} elsif ($header =~ /^Last-Modified: (.*)$/) {
			$modified = $1;
		} elsif ($header =~ /^Content-Type: (.*)$/) {
			$type = $1;
		}
	}

	$access = convert_to_time($access);
	$expires = convert_to_time($expires);
	$modified = convert_to_time($modified);

	my $exp_conf;
	if ($exp{$type}) {
		$exp_conf = $exp{$type};
	} else {
		$exp_conf = $exp{'default'};
	}

	my ($exp_type, $expected);
	if ($exp_conf =~ /^([A|M])(\d+)$/) {
		$exp_type = $1;
		$expected = $2;
	} else {
		print STDERR "\n\ndoom: $exp_conf\n\n";
		ok 0;
		last;
	}

	my $actual;
	$actual = ($expires - $modified) if ($exp_type eq 'M');
	$actual = ($expires - $access) if ($exp_type eq 'A');

	ok ($actual == $expected);

}

sub convert_to_time {
	my $timestr = shift;
	my ($sec,$min,$hours,$mday,$mon,$year);

	my %month = (	Jan => 1, Feb => 2, Mar => 3, Apr => 4,
			May => 5, Jun => 6, Jul => 7, Aug => 8,
			Sep => 9, Oct => 10, Nov => 11, Dec => 12);

	if ($timestr =~ /[A-Za-z]{3}, (\d+) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})/) {
		$mday = $1;
		$mon = $month{$2};
		$year = $3;
		$hours = $4;
		$min = $5;
		$sec = $6;
	}

	return Time::Local::timelocal($sec,$min,$hours,$mday,$mon,$year);
}

