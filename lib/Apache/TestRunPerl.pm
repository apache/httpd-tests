package Apache::TestRunPerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestRun ();

#subclass of Apache::TestRun that configures mod_perlish things

our @ISA = qw(Apache::TestRun);

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

1;
