package Apache::TestRunPerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestRun ();
use Apache::TestConfigParse ();

use File::Spec::Functions qw(catfile);

#subclass of Apache::TestRun that configures mod_perlish things
use vars qw(@ISA);
@ISA = qw(Apache::TestRun);

sub pre_configure {
    my $self = shift;

    # Apache::TestConfigPerl already configures mod_perl.so
    Apache::TestConfig::autoconfig_skip_module_add('mod_perl.c');
}

sub configure_modperl {
    my $self = shift;

    my $test_config = $self->{test_config};

    $test_config->preamble_register(qw(configure_libmodperl));

    $test_config->postamble_register(qw(configure_inc
                                        configure_trace
                                        configure_pm_tests_inc
                                        configure_startup_pl
                                        configure_pm_tests));
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
