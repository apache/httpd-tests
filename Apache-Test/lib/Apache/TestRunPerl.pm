# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache::TestRunPerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestRun ();
use Apache::TestConfigParse ();
use Apache::TestTrace;

use vars qw($VERSION);
$VERSION = '1.00'; # make CPAN.pm's r() version scanner happy

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

    my $rev = $test_config->server->{rev};
    my $ver = $test_config->server->{version};

    # sanity checking and loading the right mod_perl version
    if ($rev == 2) {
        eval { require Apache2 && require mod_perl };
    } else {
        eval { require mod_perl };
    }
    if ($@) {
        error "You are using mod_perl response handlers ",
            "but do not have a mod_perl capable Apache.";
        Apache::TestRun::exit_perl(0);
    }
    if (($rev == 1 and $mod_perl::VERSION >= 1.99) ||
        ($rev == 2 and $mod_perl::VERSION < 1.99)) {
        error "Found mod_perl/$mod_perl::VERSION, " .
            "but it can't be used with Apache/$ver";
        Apache::TestRun::exit_perl(0);
    }

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
__END__

=head1 NAME

Apache::TestRunPerl - Run mod_perl-requiring Test Suite

=head1 SYNOPSIS

  use Apache::TestRunPerl;
  Apache::TestRunPerl->new->run(@ARGV);

=head1 DESCRIPTION

The C<Apache::TestRunPerl> package controls the configuration and
running of the test suite. It's a subclass of C<Apache::TestRun>, and
should be used only when you need to run mod_perl tests.

Refer to the C<Apache::TestRun> manpage for information on the
available API.

=cut
