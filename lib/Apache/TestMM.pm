package Apache::TestMM;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();

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

sub test {

    my $env = Apache::TestConfig->passenv_makestr();

    my $preamble = <<EOF;
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
EOF

}

1;
