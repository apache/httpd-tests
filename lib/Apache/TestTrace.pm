package Apache::TestTrace;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();

use Exporter ();
use vars qw(@Levels @Utils @ISA @EXPORT $VERSION $Level $LogFH);

BEGIN {
    @Levels = qw(emerg alert crit error warning notice info debug);
    @Utils  = qw(todo);
}

@ISA     = qw(Exporter);
@EXPORT  = (@Levels, @Utils);
$VERSION = '0.01';
use subs (@Levels, @Utils);

# default settings overrideable by users
$Level = undef;
$LogFH = \*STDERR;

# private data
use constant HAS_COLOR  => eval {
    #XXX: another way to color WINFU terms?
    !(grep { $^O eq $_ } qw(MSWin32 cygwin NetWare)) and
    Apache::TestConfig::COLOR and require Term::ANSIColor;
};
use constant HAS_DUMPER => eval { require Data::Dumper;    };

# emerg => 1, alert => 2, crit => 3, ...
my %levels; @levels{@Levels} = 1..@Levels;
$levels{todo} = $levels{debug};
my $default_level = 'info'; # to prevent user typos

my %colors = ();

if (HAS_COLOR) {
    %colors = (
        emerg   => 'bold white on_blue',
        alert   => 'bold blue on_yellow',
        crit    => 'reverse',
        error   => 'bold red',
        warning => 'yellow',
        notice  => 'green',
        info    => 'cyan',
        debug   => 'magenta',
        reset   => 'reset',
        todo    => 'underline',
    );

    $Term::ANSIColor::AUTORESET = 1;

    for (keys %colors) {
        $colors{$_} = Term::ANSIColor::color($colors{$_});
    }
}
else {
    %colors = (
        emerg   => '&&&',
        alert   => '$$$',
        crit    => '%%%',
        error   => '!!!',
        warning => '***',
        notice  => '-  ',
        info    => '   ',
        debug   => '==>',
        todo    => 'todo',
    );
}

*expand = HAS_DUMPER ?
    sub { map { ref $_ ? Data::Dumper::Dumper($_) : $_ } @_ } :
    sub { @_ };

sub c_trace {
    my $level = shift;
    print $LogFH 
        map { "$colors{$level}$_$colors{reset}\n"}
        grep defined($_), expand(@_);
}

sub nc_trace {
    my $level = shift;
    print $LogFH 
        map { sprintf "%-3s %s\n", $colors{$level}, $_ } 
        grep defined($_), expand(@_);
}

{
    my $trace = HAS_COLOR ? \&c_trace : \&nc_trace;

    # if the level is sufficiently high, enable the tracing for a
    # given level otherwise assign NOP
    for my $level (@Levels,@Utils) {
        no strict 'refs';
        *$level = sub { 
            $trace->($level, @_) if trace_level() >= $levels{$level};
        };
    }
}

sub trace_level {
    # overriden by user/-trace 
    (defined $Level && $levels{$Level}) ||
    # or overriden by env var
    (exists $ENV{APACHE_TEST_TRACE_LEVEL} && 
        $levels{$ENV{APACHE_TEST_TRACE_LEVEL}}) ||
    # or default
    $levels{$default_level};
}

1;
__END__



=head1 Apache::TestTrace - Helper output generation functions

=head1 SYNOPSIS

    use Apache::TestTrace;
  
    # test sub that exercises all the tracing functions
    sub test {
        print $Apache::TestTrace::LogFH 
              "TraceLevel: $Apache::TestTrace::Level\n";
        $_->($_,[1..3],$_) for qw(emerg alert crit error
                                  warning notice info debug todo);
        print $Apache::TestTrace::LogFH "\n\n"
    };
  
    # demo the trace subs using default setting
    test();
  
    {
        # override the default trace level with 'crit'
        local $Apache::TestTrace::Level = 'crit';
        # now only 'crit' and higher levels will do tracing lower level
        test();
    }
  
    {
        # set the trace level to 'debug'
        local $Apache::TestTrace::Level = 'debug';
        # now only 'debug' and higher levels will do tracing lower level
        test();
    }
  
    {
        open OUT, ">/tmp/foo" or die $!;
        # override the default Log filehandle
        local $Apache::TestTrace::LogFH = \*OUT;
        # now the traces will go into a new filehandle
        test();
        close OUT;
    }
  
    # override tracing level via -trace opt
    % t/TEST -trace=crit
  
    # override tracing level via env var
    % env APACHE_TEST_TRACE_LEVEL=crit t/TEST

=head1 DESCRIPTION

This module exports a number of functions that make it easier
generating various diagnostics messages in your programs in a
consistent way and saves some keystrokes as it handles the new lines
and sends the messages to STDERR for you.

This module provides the same trace methods as syslog(3)'s log
levels. Listed from low level to high level: emerg(), alert(), crit(),
error(), warning(), notice(), info(), debug(). The only different
function is warning(), since warn is already taken by Perl.

The module provides another trace function called todo() which is
useful for todo items. It has the same level as I<debug> (the
highest).

If you have C<Term::ANSIColor> installed the diagnostic messages will
be colorized, otherwise a special for each function prefix will be
used.

If C<Data::Dumper> is installed and you pass a reference to a variable
to any of these functions, the variable will be dumped with
C<Data::Dumper::Dumper()>.

Functions whose level is above the level set in
C<$Apache::TestTrace::Level> become NOPs. For example if the level is
set to I<alert>, only alert() and emerg() functions will generate the
output. The default setting of this variable is I<warning>. Other
valid values are: I<emerg>, I<alert>, I<crit>, I<error>, I<warning>,
I<notice>, I<info>, I<debug>.

Another way to affect the trace level is to set
C<$ENV{APACHE_TEST_TRACE_LEVEL}>, which takes effect if
C<$Apache::TestTrace::Level> is not set. So an explicit setting of
C<$Apache::TestTrace::Level> always takes precedence.

By default all the output generated by these functions goes to
STDERR. You can override the default filehandler by overriding
C<$Apache::TestTrace::LogFH> with a new filehandler.

When you override this package's global variables, think about
localizing your local settings, so it won't affect other modules using
this module in the same run.

=head1 TODO

 o provide an option to disable the coloring altogether via some flag
   or import()

=head1 AUTHOR

Stas Bekman with contributions from Doug MacEachern

=cut

