package Apache::TestMM;

use strict;
use warnings FATAL => 'all';

use Config;
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

sub generate_script {
    my $file = shift;
    unlink $file if -e $file;
    open my $in, "$file.PL" or die "Couldn't open $file.PL: $!";
    open my $out, '>', $file or die "Couldn't open $file: $!";
    print "generating script...$file\n";
    print $out "#!$Config{perlpath}\n",
               "# WARNING: this file is generated, edit $file.PL instead\n",
               join '', <$in>;
    close $out or die "close $file: $!";
    close $in;
    chmod 0544, $file;
}

1;
