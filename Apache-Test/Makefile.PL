use 5.005;

use lib qw(lib);
use Apache::Test5005compat;

use strict;
use warnings;

# is this file was invoked directly via perl, or via the top-level
# Makefile.PL, top-level sets this env var
use constant TOP_LEVEL => !exists $ENV{MOD_PERL_2_BUILD};

use ExtUtils::MakeMaker;
use Symbol;
use File::Spec::Functions qw(catfile);
use FindBin;

use Apache::TestMM qw(test); #enable 'make test'
use Apache::TestRun;

my $VERSION;

Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);

for (@scripts) {
    Apache::TestMM::generate_script($_);
}

set_version();

# if built with mod_perl 2.0, its top-level Makefile.PL already
# installs the uninstall code
if (TOP_LEVEL) {
    require "./install-pl";
    add_Apache__test_target();
}

write_custom_config_file_stub();

WriteMakefile(
    NAME      => 'Apache::Test',
    VERSION   => $VERSION,
    PREREQ_PM => { 'File::Spec' => '0.8' },
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


sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add/;
}

sub add_Apache__test_target {
    use subs qw(MY::install MY::top_targets);
    *MY::install = sub {
        my $self = shift;

        my $string = $self->MM::install(@_);
        add_dep(\$string, pure_install => 'nuke_Apache__test');
        $string;
    };

    *MY::top_targets  = sub {
        my $self = shift;
        my $string = $self->MM::top_targets;

        $string .= Apache::Test::install::nuke_Apache__test_target();

        $string;
    };
}

# write the custom test file so it'll be copied to blib if updated
# during 'make test' and then installed system-wide
sub write_custom_config_file_stub {
    # It doesn't matter whether it gets written under modperl-2.0/lib
    # or Apache-Test/lib root, since Apache::TestRun uses the same
    # logic and will update that file with real config data, which
    # 'make install' will then pick and install system-wide
    my $path = catfile $FindBin::Bin, "lib",
        Apache::TestRun::CUSTOM_CONFIG_FILE;
    # write an empty stub
    Apache::TestRun::custom_config_write($path, '');
}

