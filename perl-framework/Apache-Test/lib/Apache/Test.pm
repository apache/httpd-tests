package Apache::Test;

use strict;
use warnings FATAL => 'all';

use Test qw(ok skip);
use Exporter ();

our @ISA = qw(Exporter);
our @EXPORT = qw(ok skip plan have_lwp);
our $VERSION = '0.01';

#so Perl's Test.pm can be run inside mod_perl
sub test_pm_refresh {
    $Test::TESTOUT = \*STDOUT;
    $Test::planned = 0;
    $Test::ntest = 1;
}

sub init_test_pm {
    my $r = shift;

    if (defined &Apache::RequestRec::TIEHANDLE) {
        tie *STDOUT, $r unless tied *STDOUT; #SetHandler perl-script will tie
    }
    else {
        $r->send_http_header; #1.xx
    }

    $r->content_type('text/plain');

    test_pm_refresh();
}

sub plan {
    init_test_pm(shift) if ref $_[0];

    my $condition = pop @_ if ref $_[-1];
    if ($condition) {
        unless (defined &have_lwp) {
            #XXX figure out a better set this up
            #dont want to require Apache::TestRequest/lwp
            #on the server side
            require Apache::TestRequest;
            *have_lwp = \&Apache::TestRequest::has_lwp;
        }
        unless ($condition->()) {
            print "1..0\n";
            exit; #XXX: Apache->exit
        }
    }

    Test::plan(@_);
}

package Apache::TestToString;

sub TIEHANDLE {
    my $string = "";
    bless \$string;
}

sub PRINT {
    my $string = shift;
    $$string .= join '', @_;
}

sub start {
    tie *STDOUT, __PACKAGE__;
    Apache::Test::test_pm_refresh();
}

sub finish {
    my $s;
    {
        my $o = tied *STDOUT;
        $s = $$o;
    }
    untie *STDOUT;
    $s;
}

1;
__END__


=head1 NAME

Apache::Test - Test.pm wrapper with helpers for testing Apache

=head1 SYNOPSIS

    use Apache::Test;

=head1 DESCRIPTION

B<Apache::Test> is a wrapper around the standard I<Test.pm> with
helpers for testing an Apache server.

=head1 FUNCTIONS

=over 4

=item plan

This function is a wrapper around I<Test::plan>.  If the first
argument is an object, such as an I<Apache::RequestRec> object,
C<STDOUT> will be tied to it.  If the last argument is a B<CODE>
reference, the tests will be skipped if the function returns false.
The I<Test.pm> global state will also be refreshed by calling
I<Apache::Test::test_pm_refresh>.  All other arguments are passed through
to I<Test::plan>. Examples:

    # just like using Test.pm, plan 3 tests
    plan tests => 3;

    # if condition() returns false, all the tests are skipped. 
    # e.g.: skip all tests if LWP is not available
    plan tests => 5, \&have_lwp;

    # first tie STDOUT to the request
    plan $r, tests => 7;

=item ok

Same as I<Test::ok>, see I<Test.pm> documentation.

=item skip

Same as I<Test::skip>, see I<Test.pm> documentation.

=item test_pm_refresh

Normally called by I<Apache::Test::plan>, this function will refresh
the global state maintained by I<Test.pm>, allowing C<plan> and
friends to be called more than once per-process.  This function is not
exported.

=back

=head1 Apache::TestToString Class

The I<Apache::TestToString> class is used to capture I<Test.pm> output
into a string.  Example:

    Apache::TestToString->start;

    plan tests => 4;

    ok $data eq 'foo';

    ...

    # $tests will contain the Test.pm output: 1..4\nok 1\n...
    my $tests = Apache::TestToString->finish;

=cut
