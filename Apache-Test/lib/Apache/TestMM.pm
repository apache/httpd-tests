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
        *{"MM::$section"} = \&{$section};
    }
}

sub passenv {
    my $passenv = Apache::TestConfig->passenv;
    my @vars;

    for (keys %$passenv) {
        push @vars, "$_=\$($_)";
    }

    "@vars";
}

sub test {

    my $env = passenv();

    my $preamble = <<EOF;
PASSENV = $env
EOF

    return $preamble . <<'EOF';
test_clean :
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST -clean
	
run_tests :
	$(PASSENV) \
	$(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	t/TEST

test :: pure_all run_tests test_clean
EOF

}

1;
