use 5.005;

use lib qw(lib);
use Apache::Test5005compat;

use strict;
use warnings;

# was this file invoked directly via perl, or via the top-level
# (mp2) Makefile.PL? if top-level, this env var will be set
use constant TOP_LEVEL => !exists $ENV{MOD_PERL_2_BUILD};

use ExtUtils::MakeMaker;
use Symbol;
use File::Find qw(finddepth);

use Apache::TestMM qw(test clean); #enable 'make test and make clean'
use Apache::TestRun;
use Apache::TestTrace;
use Apache::TestConfig ();

my $VERSION;
set_version();

sanity_check();

Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);

finddepth(sub {
    return unless /(.*?\.pl)\.PL$/;
    push @scripts, "$File::Find::dir/$1";
}, '.');

for (@scripts) {
    Apache::TestMM::generate_script($_);
}


# if built with mod_perl 2.0, its top-level Makefile.PL already
# installs the uninstall code
if (TOP_LEVEL) {
    require "./install-pl";
    add_Apache__test_target();
}

Apache::TestConfig::custom_config_file_stub_write();

my @clean_files =
    qw(lib/Apache/TestConfigData.pm
       .mypacklist
       t/TEST
       Makefile.old
      );

my %prereq = (
    'File::Spec' => '0.8',
    'Cwd'        => '2.06',
);

WriteMakefile(
    NAME      => 'Apache::Test',
    VERSION   => $VERSION,
    PREREQ_PM => \%prereq,
    dist      => {
        COMPRESS => 'gzip -9f', SUFFIX => 'gz',
    },
    clean     => {
        FILES => "@clean_files",
    },
);

# after CPAN/CPANPLUS had a chance to satisfy the requirements,
# enforce those (for those who run things manually)
check_prereqs();

sub check_prereqs {
    my %fail = ();
    for (keys %prereq) {
        unless (chk_version($_, $prereq{$_})) {
            $fail{$_} = $prereq{$_};
        }
    }
    if (%fail) {
        error "\nThe following Apache-Test dependencies aren't satisfied:",
            map { "\t$_: $fail{$_}" } keys %fail;
        error "Install those from http://search.cpan.org and try again";
        exit 0;
    }
}

sub chk_version {
    my($pkg, $wanted) = @_;

    no strict 'refs';
    local $| = 1;

    print "Checking for $pkg...";
    (my $p = $pkg . ".pm") =~ s#::#/#g;
    eval { require $p;};
    print("not ok\n$@"), return if $@;

    my $vstr = ${"${pkg}::VERSION"} ? "found v" . ${"${pkg}::VERSION"}
        : "not found";
    my $vnum = ${"${pkg}::VERSION"} || 0;

    print $vnum >= $wanted ? "ok\n" : " " . $vstr . "\n";

    $vnum >= $wanted;
}

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

sub sanity_check {
    # don't allow running an explicit 'perl Makefile.PL', when
    # Apache-Test is checked out into the modperl-2.0 tree, since
    # it then decides that it's a part of the modperl-2.0 build and
    # will try to use modperl httpd/apxs arguments which could be
    # unset or wrong
    if (TOP_LEVEL && -e "../lib/mod_perl.pm") {
        error "Do not run 'perl Makefile.PL' when Apache-Test is a " .
            "subdirectory of modperl-2.0. Copy it elsewhere and run " .
            "from there.";
        Apache::TestRun::exit_perl(0);
    }
}

if ($ExtUtils::MakeMaker::VERSION < 6.06) {
    # now that we're using subversion, make sure that
    # .svn directories are skipped during the build process
    # for old versions of MakeMaker

    sub MY::libscan {
        my $self = shift;

        my $path = shift;

        return '' if $path =~ /\B\.svn\b/;

        return $path;
    }
}

sub MY::postamble {
    my $self = shift;

    my $string = $self->MM::postamble;

    $string .= <<'EOF';
tag :
	svn copy . https://svn.apache.org/repos/asf/httpd/test/tags/APACHE_TEST_$(VERSION_SYM)
	@echo update lib/Apache/Test.pm VERSION now
EOF

    return $string;
}

sub MY::constants {
    my $self = shift;

    my $string = $self->MM::constants;

    # mp2 installs A-T into INSTALLSITEARCH, so in order to avoid
    # problems when users forget 'make install UNINST=1', trick MM into
    # installing pure perl modules to the sitearch location, when A-T is
    # not installed as a part of mp2 build
    if (TOP_LEVEL) {
        $string .= <<'EOI';

# install into the same location as mod_perl 2.0
INSTALLSITELIB = $(INSTALLSITEARCH)
DESTINSTALLSITELIB = $(DESTINSTALLSITEARCH)
EOI
    }

    $string;
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
