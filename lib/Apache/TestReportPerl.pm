package Apache::TestReportPerl;

use strict;
use warnings FATAL => 'all';

use Apache::TestReport ();
use ModPerl::Config ();

# a subclass of Apache::TestReport that generates a bug report script
use vars qw(@ISA);
@ISA = qw(Apache::TestReport);

sub config {
    ModPerl::Config::as_string();
}

sub report_to { 'dev@perl.apache.org' }

1;
__END__
