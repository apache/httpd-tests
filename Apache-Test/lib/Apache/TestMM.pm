package Apache::TestMM;

use strict;
use warnings FATAL => 'all';

use Config;
use Apache::TestConfig ();
use Apache::TestTrace;

sub import {
    my $class = shift;

    for my $section (@_) {
        unless (defined &$section) {
            die "unknown Apache::TestMM section: $section";
        }
        no strict 'refs';
        my $sub = "MY::$section";
        # Force aliasing, since previous WriteMakefile might have
        # moved it
        undef &$sub if defined &$sub;
        *$sub = \&{$section};
    }
}

sub add_dep {
    my($string, $targ, $add) = @_;
    $$string =~ s/($targ\s+::)/$1 $add /;
}

sub clean {
    my $self = shift;
    my $string = $self->MM::clean(@_);
    add_dep(\$string, clean => 'test_clean');
    $string;
}

sub test {

    my $env = Apache::TestConfig->passenv_makestr();

    my $preamble = Apache::TestConfig::WIN32 ? "" : <<EOF;
PASSENV = $env
EOF

    return $preamble . <<'EOF';
TEST_VERBOSE = 0
TEST_FILES =

test_clean :
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -clean

run_tests : test_clean
	$(PASSENV) \
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -verbose=$(TEST_VERBOSE) $(TEST_FILES)

test :: pure_all run_tests test_clean

cmodules:
	cd c-modules && $(MAKE) all

cmodules_clean:
	cd c-modules && $(MAKE) clean
EOF

}

sub generate_script {
    my $file = shift;

    unlink $file if -e $file;

    my $body = "use blib;\n";

    $body .= Apache::TestConfig->modperl_2_inc_fixup;

    if (@Apache::TestMM::Argv) {
        $body .= "\n\%Apache::TestConfig::Argv = qw(@Apache::TestMM::Argv);\n";
    }

    my $in = Symbol::gensym();
    open $in, "$file.PL" or die "Couldn't open $file.PL: $!";
    {
        local $/;
        $body .= <$in>;
    }
    close $in;

    info "generating script $file";
    Apache::Test::config()->write_perlscript($file, $body);
}

sub filter_args {
    my($argv, $vars) =
        Apache::TestConfig::filter_args(\@ARGV, \%Apache::TestConfig::Usage);
    @ARGV = @$argv;
    @Apache::TestMM::Argv = %$vars;
}

1;
