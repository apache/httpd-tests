use 5.005;

use ExtUtils::MakeMaker;
use Symbol;

use lib qw(lib);

my $VERSION;

use File::Spec::Functions qw(catfile catdir);

use Apache::Test5005compat;

use Apache::TestMM qw(test); #enable 'make test'

my $cleanup_packlist = ".mypacklist";

Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);

for (@scripts) {
    Apache::TestMM::generate_script($_);
}

set_version();

nuke_Apache__test();

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


# on Case-Insensitive systems Apache/Test.pm can't coexist with
# Apache/test.pm, since Apache::test is now deprecated (was renamed to
# Apache/testold.pm in mod_perl 1.28, we need to find and remove any
# occurrences of this file. CPAN authors should
# s/Apache::test/Apache::testold/ and can either require mod_perl 1.28
# which already carries it or simply bundle it. The best option is to
# port the test suite to use Apache::Test which works with both
# mod_perl generations.
#
# we could have done this cleanup only for case-insensitive systems,
# but I feel that doing it for all systems, will speedup the
# transitions from Apache::test to either Apache::Test or
# Apache::testold.
#
sub nuke_Apache__test {

    my @convicts = ();
    foreach (@INC) {
        my $dir = catdir $_, "Apache";
        next unless -d $dir;
        opendir DIR, $dir or die "Cannot opendir $dir: $!\n";
        my @matches = grep /^test.pm$/, readdir DIR;
        closedir DIR;
        push @convicts, map { catfile $dir, $_ } @matches if @matches;
    }

    if (@convicts) {
        print <<EOI;
!!! Makefile.PL has found old copies of Apache/test.pm which will
be removed during 'make install' to prevent collisions with Apache::Test:

@{[join "\n", @convicts]}

CPAN authors are advised to either use Apache::testold or port their
test suite to Apache::Test which works with both mod_perl generations.
EOI
    }

    open PACKLIST, ">$cleanup_packlist"
        or die "Can't open $cleanup_packlist: $!";
    print PACKLIST join "", map "$_\n", @convicts;
    close PACKLIST;
}

sub MY::install {
    my $self = shift;

    my $string = $self->MM::install(@_);
    add_dep(\$string, pure_install => 'nuke_Apache__test');

    $string;
}

sub MY::top_targets {
    my $self = shift;
    my $string = $self->MY::top_targets;

    $string .= <<EOF;

nuke_Apache__test:
\t\$(PERLRUN) -MExtUtils::Install -e "uninstall(qq{$cleanup_packlist}, 1, 0)"
EOF

    $string;
}

sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add/;
}
