package Apache::TestRunPerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestRun ();

use File::Spec::Functions qw(catfile);

#subclass of Apache::TestRun that configures mod_perlish things
use vars qw(@ISA);
@ISA = qw(Apache::TestRun);

sub configure_modperl {
    my $self = shift;

    my $test_config = $self->{test_config};

    $test_config->preamble_register(qw(configure_libmodperl));

    $test_config->postamble_register(qw(configure_inc
                                        configure_pm_tests
                                        configure_startup_pl));
}

sub configure {
    my $self = shift;

    $self->configure_modperl;

    $self->SUPER::configure;
}

#if Apache::TestRun refreshes config in the middle of configure
#we need to re-add modperl configure hooks
sub refresh {
    my $self = shift;
    $self->SUPER::refresh;
    $self->configure_modperl;
}

# generate t/TEST script (or a different filename) which will drive
# Apache::TestRunPerl
sub generate_script {
    my ($class, $file) = @_;

    $file ||= catfile 't', 'TEST';

    my $content = <<'EOM';
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../Apache-Test/lib";

use Apache::TestRunPerl ();

Apache::TestRunPerl->new->run(@ARGV);
EOM

    Apache::Test::config()->write_perlscript($file, $content);

}


1;
