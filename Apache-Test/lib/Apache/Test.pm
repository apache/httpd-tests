package Apache::Test;

use strict;
use warnings FATAL => 'all';

use Test qw(ok skip);
use Exporter ();
use Config;
use Apache::TestConfig ();

use vars qw(@ISA @EXPORT $VERSION %SubTests @SkipReasons);

@ISA = qw(Exporter);
@EXPORT = qw(ok skip sok plan skip_unless have_lwp have_http11
             have_cgi have_module have_apache have_perl);
$VERSION = '0.01';

%SubTests = ();
@SkipReasons = ();

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
        untie *STDOUT if tied *STDOUT;
        tie *STDOUT, $r;
    }
    else {
        $r->send_http_header; #1.xx
    }

    $r->content_type('text/plain');

    test_pm_refresh();
}

sub have_http11 {
    require Apache::TestRequest;
    if (Apache::TestRequest::install_http11()) {
        return 1;
    }
    else {
        push @SkipReasons,
           "LWP version 5.60+ required for HTTP/1.1 support";
        return 0;
    }
}

sub have_ssl {
    my $vars = vars();
    have_module([$vars->{ssl_module_name}, 'Net::SSL']);
}

sub have_lwp {
    require Apache::TestRequest;
    if (Apache::TestRequest::has_lwp()) {
        return 1;
    }
    else {
        push @SkipReasons, "libwww-perl is not installed";
        return 0;
    }
}

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
            else {
                die "don't know how to handle a condition of type $ref";
            }
        }
        else {
            # we have the verdict already: true/false
            $meets_condition = $condition ? 1 : 0;
        }

        # tryint to emulate a dual variable (ala errno)
        unless ($meets_condition) {
            my $reason = join ', ',
              @SkipReasons ? @SkipReasons : "no reason given";
            print "1..0 # skipped: $reason\n";
            exit; #XXX: Apache->exit
        }
    }
    @SkipReasons = (); # reset

    Test::plan(@_);
}

sub skip_unless {
    my $condition = shift;
    my $reason = shift || "no reason given";

    if (ref $condition eq 'CODE' and $condition->()) {
        return 1;
    }
    else {
        push @SkipReasons, $reason;
        return 0;
    }
}

sub have_module {
    my $cfg = config();
    my @modules = ref($_[0]) ? @{ $_[0] } : @_;

    my @reasons = ();
    for (@modules) {
        if (/^[a-z0-9_]+$/) {
            my $mod = $_;
            $mod = 'mod_' . $mod unless $mod =~ /^mod_/;
            $mod .= '.c' unless $mod =~ /\.c$/;
            next if $cfg->{modules}->{$mod};
            if (exists $cfg->{cmodules_disabled}->{$mod}) {
                push @reasons, $cfg->{cmodules_disabled}->{$mod};
                next;
            }
        }
        die "bogus module name $_" unless /^[\w:.]+$/;
        eval "require $_";
        #print $@ if $@;
        if ($@) {
            push @reasons, "cannot find module '$_'";
            next;
        }
    }
    if (@reasons) {
        push @SkipReasons, @reasons;
        return 0;
    }
    else {
        return 1;
    }
}

sub have_cgi {
    have_module('cgi') || have_module('cgid');
}

sub have_apache {
    my $version = shift;
    my $cfg = Apache::Test::config();
    my $rev = $cfg->{server}->{rev};

    if ($rev == $version) {
        return 1;
    }
    else {
        push @SkipReasons,
          "apache version $version required, this is version $rev";
        return 0;
    }
}

sub config_enabled {
    my $key = shift;
    defined $Config{$key} and $Config{$key} eq 'define';
}

sub have_perl {
    my $thing = shift;
    #XXX: $thing could be a version
    my $config;

    for my $key ($thing, "use$thing") {
        if (exists $Config{$key}) {
            $config = $key;
            return 1 if config_enabled($key);
        }
    }

    push @SkipReasons, $config ?
      "Perl was not built with $config enabled" :
        "$thing is not available with this version of Perl";

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

B<Apache::Test> is a wrapper around the standard C<Test.pm> with
helpers for testing an Apache server.

=head1 FUNCTIONS

=over 4

=item plan

This function is a wrapper around C<Test::plan>:

    plan tests => 3;

just like using Test.pm, plan 3 tests.

If the first argument is an object, such as an C<Apache::RequestRec>
object, C<STDOUT> will be tied to it. The C<Test.pm> global state will
also be refreshed by calling C<Apache::Test::test_pm_refresh>. For
example:

    plan $r, tests => 7;

ties STDOUT to the request object C<$r>.

If there is a last argument that doesn't belong to C<Test::plan>
(which expects a balanced hash), it's used to decide whether to
continue with the test or to skip it all-together. This last argument
can be:

=over

=item * a C<SCALAR>

the test is skipped if the scalar has a false value. For example:

  plan tests => 5, 0;

But this won't hint the reason for skipping therefore it's better to
use skip_unless():

  plan tests => 5, skip_unless(sub { $a == $b }, "$a != $b");

see skip_unless() for more info.

=item * an C<ARRAY> reference

have_module() is called for each value in this array. The test is
skipped if have_module() returns false (which happens when at least
one C or Perl module from the list cannot be found).

=item * a C<CODE> reference

the tests will be skipped if the function returns a false value. For
example:

    plan tests => 5, \&have_lwp;

the test will be skipped if LWP is not available

=back

All other arguments are passed through to I<Test::plan> as is.

=item ok

Same as I<Test::ok>, see I<Test.pm> documentation.

=item sok

Allows to skip a sub-test, controlled from the command line.  The
argument to sok() is a CODE reference or a BLOCK whose return value
will be passed to ok(). By default behaves like ok(). If all sub-tests
of the same test are written using sok(), and a test is executed as:

  % ./t/TEST -v skip_subtest 1 3

only sub-tests 1 and 3 will be run, the rest will be skipped.

=item skip

Same as I<Test::skip>, see I<Test.pm> documentation.

=item skip_unless

  skip_unless($cond_sub, $reason);

skip_unless() is used with plan(), it executes C<$cond_sub> code
reference and if it returns a false value C<$reason> gets printed as a
reason for test skipping.

see plan().

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
