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
        #e.g. modperl-2.0/Makefile.PL pulls in Apache-Test/Makefile.PL
        next if defined &$sub;
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
test_clean :
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -clean
	
run_tests : test_clean
	$(PASSENV) \
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST

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
    my $in = Symbol::gensym();
    my $out = Symbol::gensym();
    open $in, "$file.PL" or die "Couldn't open $file.PL: $!";
    open $out, ">$file" or die "Couldn't open $file: $!";

    info "generating script $file";

    print $out "#!$Config{perlpath}\n",
               "# WARNING: this file is generated, edit $file.PL instead\n";

    if (@Apache::TestMM::Argv) {
        print $out "\%Apache::TestConfig::Argv = qw(@Apache::TestMM::Argv);\n";
    }

    print $out join '', <$in>;

    close $out or die "close $file: $!";
    close $in;
    chmod 0555, $file;
}

sub filter_args {
    my($argv, $vars) =
      Apache::TestConfig::filter_args(\@ARGV,
                                      \%Apache::TestConfig::Usage);
    @ARGV = @$argv;
    @Apache::TestMM::Argv = %$vars;
}

1;
