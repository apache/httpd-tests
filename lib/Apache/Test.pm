package Apache::Test;

use strict;
use warnings FATAL => 'all';

use Test qw(ok skip);
use Exporter ();
use Config;
use Apache::TestConfig ();

use vars qw(@ISA @EXPORT $VERSION %SubTests);

@ISA = qw(Exporter);
@EXPORT = qw(ok skip sok plan have_lwp have_http11 have_cgi
             have_module have_apache have_perl);
$VERSION = '0.01';

%SubTests = ();

if (my $subtests = $ENV{HTTPD_TEST_SUBTESTS}) {
    %SubTests = map { $_, 1 } split /\s+/, $subtests;
}

my $Config;

sub config {
    $Config ||= Apache::TestConfig->thaw;
}

sub vars {
    config()->{vars};
}

sub sok (&;$) {
    my $sub = shift;
    my $nok = shift || 1; #allow sok to have 'ok' within

    if (%SubTests and not $SubTests{ $Test::ntest }) {
        for my $n (1..$nok) {
            skip "skipping this subtest", 0;
        }
        return;
    }

    ok $sub->();
}

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

#caller will need to have required Apache::TestRequest
*have_http11 = \&Apache::TestRequest::install_http11;
*have_lwp = \&Apache::TestRequest::has_lwp;

sub plan {
    init_test_pm(shift) if ref $_[0];

    # extending Test::plan's functionality, by using the optional
    # single value in @_ coming after a ballanced %hash which
    # Test::plan expects
    if (@_ % 2) {
        my $condition = pop @_;
        my $ref = ref $condition;
        my $meets_condition = 0;
        if ($ref) {
            if ($ref eq 'CODE') {
                #plan tests $n, \&has_lwp
                $meets_condition = $condition->();
            }
            elsif ($ref eq 'ARRAY') {
                #plan tests $n, [qw(php4 rewrite)];
                $meets_condition = have_module($condition);
            }
        }
        else {
            # we have the verdict already: true/false
            $meets_condition = $condition ? 1 : 0;
        }

        unless ($meets_condition) {
            print "1..0\n";
            exit; #XXX: Apache->exit
        }
    }

    Test::plan(@_);
}

sub have_module {
    my $cfg = config();
    my @modules = ref($_[0]) ? @{ $_[0] } : @_;

    for (@modules) {
        if (/^[a-z0-9_]+$/) {
            my $mod = $_;
            $mod = 'mod_' . $mod unless $mod =~ /^mod_/;
            $mod .= '.c' unless $mod =~ /\.c$/;
            next if $cfg->{modules}->{$mod};
        }
        die "bogus module name $_" unless /^[\w:.]+$/;
        eval "require $_";
        #print $@ if $@;
        return 0 if $@;
    }

    return 1;
}

sub have_cgi {
    [have_module('cgi') || have_module('cgid')];
}

sub have_apache {
    my $version = shift;
    my $cfg = Apache::Test::config();
    $cfg->{server}->{rev} == $version;
}

sub have_perl {
    my $thing = shift;
    #XXX: $thing could be a version
    for my $key ($thing, "use$thing") {
        return 1 if $Config{$key} and $Config{$key} eq 'define';
    }
    return 0;
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
