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

## calculate "modification plus 10 years 6 months 2 weeks 3 days 12 hours 30 minutes 19 seconds"
my $exp_years =     10 * 60 * 60 * 24 * 365;
my $exp_months =    6 * 60 * 60 * 24 * 30;
my $exp_weeks =     2 * 60 * 60 * 24 * 7;
my $exp_days =      3 * 60 * 60 * 24;
my $exp_hours =     12 * 60 * 60;
my $exp_minutes =   30 * 60;
my $expires_default = $exp_years + $exp_months + $exp_weeks +
                    $exp_days + $exp_hours + $exp_minutes + 19;

my @page = qw(index.html text.txt image.gif foo.jpg);
my %exp  = 
    (	
     'default'    => "M$expires_default",
     'text/plain' => 'M60',
     'image/gif'  => 'A120',
     'image/jpeg' => 'A86400'
    );

my %names =
    (
     'Date'          => 'access',
     'Expires'       => 'expires',
     'Last-Modified' => 'modified',
     'Content-Type'  => 'type',
    );

my %month = ();
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
#@month{@months} = 1..@months;
@month{@months} = 0..@months-1;

plan tests => @page * 2, test_module 'expires';

foreach my $page (@page) {
    my $head = HEAD_STR "/modules/expires/$page";
    $head = '' unless defined $head;
    print "debug: $page\n$head\n";
    ok ($head =~ /^HTTP\/1\.[1|0] 200 OK/);

    my %headers = ();
    foreach my $header (split /\n/, $head) {
        if ($header =~ /^([\-\w]+): (.*)$/) {
            print "debug: [$1] [$2]\n";
            $headers{$names{$1}} = $2 if exists $names{$1};
        }
    }

    for my $h (grep !/^type$/, values %names) {
        print "debug: $h @{[$headers{$h}||'']}\n";
        if ($headers{$h}) {
            $headers{$h} = convert_to_time($headers{$h}) || 0;
        } else {
            $headers{$h} = 0;
        }
        print "debug: $h $headers{$h}\n";
    }

    my $exp_conf = '';
    if ( exists $exp{ $headers{type} } and $exp{ $headers{type} }) {
        $exp_conf = $exp{ $headers{type} };
    } else {
        $exp_conf = $exp{'default'};
    }

    my $expected = '';
    my $exp_type = '';
    if ($exp_conf =~ /^([A|M])(\d+)$/) {
        $exp_type = $1;
        $expected = $2;
    } else {
        print STDERR "\n\ndoom: $exp_conf\n\n";
        ok 0;
        last;
    }

    my $actual = 0;
    if ($exp_type eq 'M') {
        $actual = $headers{expires} - $headers{modified};
    } elsif ($exp_type eq 'A') {
        $actual = $headers{expires} - $headers{access};
    }

    print "debug: expected: $expected\n";
    print "debug: actual  : $actual\n";
    ok ($actual == $expected);

}



sub convert_to_time {
    my $timestr = shift;
    return undef unless $timestr;

    my ($sec,$min,$hours,$mday,$mon,$year);
    if ($timestr =~ /^\w{3}, (\d+) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}).*$/) {
        $mday  = $1;
        $mon   = $month{$2};
        $year  = $3;
        $hours = $4;
        $min   = $5;
        $sec   = $6;
    }

    return undef 
        unless 
            defined $sec   && 
            defined $min   && 
            defined $hours && 
            defined $mday  && 
            defined $mon   && 
            defined $year;

    return Time::Local::timegm($sec, $min, $hours, $mday, $mon, $year);
}
