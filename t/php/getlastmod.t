use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest qw(GET_BODY);
use Apache::TestUtil;
use File::Spec::Functions qw(catfile);

use POSIX qw(strftime);

plan tests => 1, have_module 'php4';

my $vars = Apache::Test::vars();
my $fname = catfile $vars->{documentroot}, "php", "getlastmod.php";
my $mtime = (stat($fname))[9] || die "could not find file";
my $month = strftime "%B", gmtime($mtime);

ok t_cmp(
    $month,
    GET_BODY("/php/getlastmod.php"),
    "getlastmod()"
);
