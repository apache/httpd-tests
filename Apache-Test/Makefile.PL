use 5.005;

use ExtUtils::MakeMaker;
use Symbol;

use lib qw(lib);

my $VERSION;

use Apache::Test5005compat;

use Apache::TestMM qw(test); #enable 'make test'

Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);

for (@scripts) {
    Apache::TestMM::generate_script($_);
}

set_version();

WriteMakefile(
    NAME      => 'Apache::Test',
    VERSION   => $VERSION,
    dist      => {
	COMPRESS => 'gzip -9f', SUFFIX=>'gz',
    },
);

sub set_version {
    $VERSION = $Apache::Test::VERSION;

    my $fh = Symbol::gensym();
    open $fh, 'Changes' or die "Can't open Changes: $!";
    while (<$fh>) {
	if(/^=item.*-dev/) {
	    $VERSION .= '-dev';
	    last;
	}
	last if /^=item/;
    }
    close $fh;

}

sub MY::postamble {
    my $self = shift;

    my $string = $self->MM::postamble;

    $string .= <<'EOF';
cvs_tag :
	cvs tag APACHE_TEST_$(VERSION_SYM) .
	@echo update lib/Apache/Test.pm VERSION now
EOF

    return $string;
}

