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

Apache::Test -- Run tests with mod_perl-enabled Apache server

=head1 SYNOPSIS

    use Apache::Test;

    # plan 3 tests
    plan tests => 3, \&condition;

    # if condition() returns false, all the tests are skipped. 
    # e.g.: skip all tests if LWP is not available
    plan tests => 5, \&have_lwp;

    # ok() and skip() are imported from Test.pm (see Test.pm manpage)
    ok 'mod_perl rules'; # test 1 is passed (the string is true)
    ok 42;               # test 2 is passed (42 is always true)
    skip "why 42?"       # test 3 is skipped (print the reason: "why 42?")
    my @a = qw(a b);
    ok $a[0] eq $a[1];   # test 4 is failed ('a' ne 'b')
    ok ++$a[0] eq $a[1]; # test 5 is passed ('b' eq 'b')

=cut

