package Apache::TestSmokePerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestSmoke ();
use ModPerl::Config ();

# a subclass of Apache::TestSmoke that configures mod_perlish things
use vars qw(@ISA);
@ISA = qw(Apache::TestSmoke);

sub build_config_as_string {
    ModPerl::Config::as_string();
}

1;
__END__

