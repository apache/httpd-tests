package Apache::TestRun;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();
use Apache::TestConfigC ();
use Apache::TestRequest ();
use Apache::TestHarness ();
use Apache::TestTrace;

use File::Find qw(finddepth);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(GetOptions);
use Config;

my @std_run      = qw(start-httpd run-tests stop-httpd);
my @others       = qw(verbose configure clean help ping ssl);
my @flag_opts    = (@std_run, @others);
my @string_opts  = qw(order);
my @ostring_opts = qw(proxy);
my @debug_opts   = qw(debug);
my @num_opts     = qw(times);
my @list_opts    = qw(preamble postamble breakpoint);
my @hash_opts    = qw(header);
my @help_opts    = qw(clean help ping);
my @exit_opts    = (@help_opts,@debug_opts);
my @request_opts = qw(get post head);

my %usage = (
   'start-httpd'     => 'start the test server',
   'run-tests'       => 'run the tests',
   'times=N'         => 'repeat the tests N times',
   'order=mode'      => 'run the tests in one of the modes: (repeat|rotate|random)',
   'stop-httpd'      => 'stop the test server',
   'verbose'         => 'verbose output',
   'configure'       => 'force regeneration of httpd.conf (tests will not be run)',
   'clean'           => 'remove all generated test files',
   'help'            => 'display this message',
   'preamble'        => 'config to add at the beginning of httpd.conf',
   'postamble'       => 'config to add at the end of httpd.conf',
   'ping'            => 'test if server is running or port in use',
   'debug[=name]'    => 'start server under debugger name (e.g. gdb, ddd, ...)',
   'breakpoint=bp'   => 'set breakpoints (multiply bp can be set)',
   'header'          => "add headers to (".join('|', @request_opts).") request",
   'ssl'             => 'run tests through ssl',
   'proxy'           => 'proxy requests (default proxy is localhost)',
   (map { $_, "\U$_\E url" } @request_opts),
);

sub fixup {
    #make sure we use an absolute path to perl
    #else Test::Harness uses the perl in our PATH
    #which might not be the one we want
    $^X = $Config{perlpath} if $^X eq 'perl';
}

sub new {
    my $class = shift;

    my $self = bless {
        tests => [],
        @_,
    }, $class;

    $self->fixup;

    $self;
}

#split arguments into test files/dirs and options
#take extra care if -e, the file matches /\.t$/
#                if -d, the dir contains .t files
#so we dont slurp arguments that are not tests, example:
# httpd $HOME/apache-2.0/bin/httpd

sub split_args {
    my($self, $argv) = @_;

    my(@tests, @args);

    for (@$argv) {
        my $arg = $_;
        #need the t/ for stat-ing, but dont want to include it in test output
        $arg =~ s:^t/::;
        my $t_dir = catfile qw(.. t);
        my $file = catfile $t_dir, $arg;

        if (-d $file and $_ ne '/') {
            my @files = <$file/*.t>;
            if (@files) {
                my $remove = catfile $t_dir, "";
                push @tests, map { s,^\Q$remove,,; $_ } @files;
                next;
            }
        }
        else {
            if ($file =~ /\.t$/ and -e $file) {
                push @tests, "$arg";
                next;
            }
            elsif (-e "$file.t") {
                push @tests, "$arg.t";
                next;
            }
        }

        push @args, $_;
    }

    $self->{tests} = \@tests;
    $self->{args}  = \@args;
}

sub passenv {
    my $passenv = Apache::TestConfig->passenv;
    for (keys %$passenv) {
        return 1 if $ENV{$_};
    }
    0;
}

sub getopts {
    my($self, $argv) = @_;

    $self->split_args($argv);

    #dont count test files/dirs as @ARGV arguments
    local *ARGV = $self->{args};
    my(%opts, %vopts, %conf_opts);

    GetOptions(\%opts, @flag_opts, @help_opts,
               (map "$_:s", @debug_opts, @request_opts, @ostring_opts),
               (map "$_=s", @string_opts),
               (map "$_=i", @num_opts),
               (map { ("$_=s", $vopts{$_} ||= []) } @list_opts),
               (map { ("$_=s", $vopts{$_} ||= {}) } @hash_opts));

    $opts{$_} = $vopts{$_} for keys %vopts;

    #force regeneration of httpd.conf if commandline args want to modify it
    $self->{reconfigure} = $opts{configure} ||
      (grep { $opts{$_}->[0] } qw(preamble postamble)) ||
        (grep { $Apache::TestConfig::Usage{$_} } @ARGV) ||
          $self->passenv() || (! -e 'conf/httpd.conf');

    while (my($key, $val) = splice @ARGV, 0, 2) {
       $conf_opts{lc $key} = $val;
    }

    if (exists $opts{debug}) {
        $opts{debugger} = $opts{debug};
        $opts{debug} = 1;
    }

    # breakpoint automatically turns the debug mode on
    if (@{ $opts{breakpoint} }) {
        $opts{debug} ||= 1;
    }

    if ($self->{reconfigure}) {
        $conf_opts{save} = 1;
    }
    else {
        $conf_opts{thaw} = 1;
    }

    #propagate some values
    for (qw(verbose)) {
        $conf_opts{$_} = $opts{$_};
    }

    $self->{opts} = \%opts;
    $self->{conf_opts} = \%conf_opts;
}

sub default_run_opts {
    my $self = shift;
    my($opts, $tests) = ($self->{opts}, $self->{tests});

    unless (grep { exists $opts->{$_} } @std_run, @request_opts) {
        if (@$tests && $self->{server}->ping) {
            #if certain tests are specified and server is running, dont restart
            $opts->{'run-tests'} = 1;
        }
        else {
            #default is server-server run-tests stop-server
            $opts->{$_} = 1 for @std_run;
        }
    }

    $opts->{'run-tests'} ||= @$tests;
}

my $caught_sig_int = 0;

sub install_sighandlers {
    my $self = shift;

    my($server, $opts) = ($self->{server}, $self->{opts});

    $SIG{__DIE__} = sub {
        return unless $_[0] =~ /^Failed/i; #dont catch Test::ok failures
        $server->stop(1) if $opts->{'start-httpd'};
        $server->failed_msg("error running tests");
    };

    $SIG{INT} = sub {
        if ($caught_sig_int++) {
            warning "\ncaught SIGINT";
            exit;
        }
        warning "\nhalting tests";
        $server->stop if $opts->{'start-httpd'};
        exit;
    };

    #try to make sure we scan for core no matter what happens
    #must eval "" to "install" this END block, otherwise it will
    #always run, a subclass might not want that

    eval "END {
             eval {
                Apache::TestRun->new(test_config =>
                                     Apache::TestConfig->thaw)->scan;
             };
         }";
}

#throw away cached config and start fresh
sub refresh {
    my $self = shift;
    $self->opt_clean;
    $self->{conf_opts}->{save} = delete $self->{conf_opts}->{thaw} || 1;
    $self->{test_config} = $self->new_test_config($self->{conf_opts});
    $self->{server} = $self->{test_config}->server;
}

sub configure_opts {
    my $self = shift;
    my $save = shift;

    my($test_config, $opts) = ($self->{test_config}, $self->{opts});

    $test_config->{vars}->{scheme} =
      $opts->{ssl} ? 'https' :
        $self->{conf_opts}->{scheme} || 'http';

    if (exists $opts->{proxy}) {
        my $max = $test_config->{vars}->{maxclients};
        $opts->{proxy} ||= $test_config->{vars}->{proxy} || 'on';

        #if config is cached and MaxClients == 1, must reconfigure
        if (!$$save and $opts->{proxy} eq 'on' and $max == 1) {
            $$save = 1;
            warning "server must be reconfigured for proxy";
            $self->refresh;
            $test_config = $self->{test_config};
        }

        $test_config->{vars}->{proxy} = $opts->{proxy};
    }

    return unless $$save;

    my $preamble  = sub { shift->preamble($opts->{preamble}) };
    my $postamble = sub { shift->postamble($opts->{postamble}) };

    $test_config->preamble_register($preamble);
    $test_config->postamble_register($postamble);
}

sub configure {
    my $self = shift;

    my $save = \$self->{conf_opts}->{save};
    $self->configure_opts($save);

    unless ($$save) {
        #update minor changes to cached config
        #without complete regeneration
        #for example this allows switching between
        #'t/TEST' and 't/TEST -ssl'
        $self->{test_config}->sync_vars(qw(scheme proxy));
        return;
    }

    my $test_config = $self->{test_config};
    $test_config->generate_ssl_conf if $self->{opts}->{ssl};
    $test_config->cmodules_configure;
    $test_config->generate_httpd_conf;
    $test_config->save;
}

sub try_exit_opts {
    my $self = shift;

    for (@exit_opts) {
        next unless $self->{opts}->{$_};
        my $method = "opt_$_";
        exit if $self->$method();
    }

    if ($self->{opts}->{'stop-httpd'}) {
        if ($self->{server}->ping) {
            $self->{server}->stop;
        }
        else {
            warning "server $self->{server}->{name} is not running";
        }
        exit;
    }
}

sub start {
    my $self = shift;

    my $test_config = $self->{test_config};

    unless ($test_config->{vars}->{httpd}) {
        error "no test server configured, please specify an httpd or ".
              ($test_config->{MP_APXS} ?
               "an apxs other than $test_config->{MP_APXS}" : "apxs").
               " or put either in your PATH";
        exit 1;
    }

    if ($self->{opts}->{'start-httpd'}) {
        exit 1 unless $self->{server}->start;
    }
    elsif ($self->{opts}->{'run-tests'} and !$self->{server}->ping) {
        # make sure that the server is up when -run-tests is used
        warning "server isn't running, attempting to start it...";
        $self->{opts}->{'stop-httpd'} = 1;
        exit 1 unless $self->{server}->start;
    }
}

sub run_tests {
    my $self = shift;

    my $test_opts = {
        verbose => $self->{opts}->{verbose},
        tests   => $self->{tests},
        times   => $self->{opts}->{times},
        order   => $self->{opts}->{order},
    };

    if (grep { exists $self->{opts}->{$_} } @request_opts) {
        run_request($self->{test_config}, $self->{opts});
    }
    else {
        Apache::TestHarness->run($test_opts)
            if $self->{opts}->{'run-tests'};
    }
}

sub stop {
    my $self = shift;

    $self->{server}->stop if $self->{opts}->{'stop-httpd'};
}

sub new_test_config {
    my $self = shift;
    Apache::TestConfig->new($self->{conf_opts});
}

sub run {
    my $self = shift;
    my(@argv) = @_;

    Apache::TestHarness->chdir_t;

    $self->getopts(\@argv);

    $self->{test_config} = $self->new_test_config;

    $self->{server} = $self->{test_config}->server;

    local($SIG{__DIE__}, $SIG{INT});
    $self->install_sighandlers;

    if ($self->{opts}->{configure}) {
        warning "cleaning out current configuration";
        $self->opt_clean;
    }

    $self->configure;

    if ($self->{opts}->{configure}) {
        warning "reconfiguration done";
        exit;
    }

    $self->try_exit_opts;

    $self->default_run_opts;

    $self->start;

    $self->run_tests;

    $self->stop;
}

my @oh = qw(jeez golly gosh darn shucks dangit rats nuts dangnabit crap);
sub oh {
    $oh[ rand scalar @oh ];
}

sub scan {
    my $self = shift;
    my $vars = $self->{test_config}->{vars};
    my $times = 0;

    finddepth(sub {
        return unless /^core$/;
        my $core = "$File::Find::dir/$_";
        my $oh = oh();
        my $again = $times++ ? "again" : "";
        error "oh $oh, server dumped core $again";
        error "for stacktrace, run: gdb $vars->{httpd} -core $core";
    }, $vars->{top_dir});
}

sub run_request {
    my($test_config, $opts) = @_;

    my @args = %{ $opts->{header} };
    my $wanted_args = Apache::TestRequest::wanted_args();

    while (my($key, $val) = each %{ $test_config->{vars} }) {
        next unless $wanted_args->{$key};
        push @args, $key, $val;
        delete $test_config->{vars}->{$key}; #dont save these
    }

    my($request, $url) = ("", "");

    for (@request_opts) {
        next unless exists $opts->{$_};
        $url = $opts->{$_} if $opts->{$_};
        $request = join $request ? '_' : '', $request, $_;
    }

    if ($request) {
        my $method = \&{"Apache::TestRequest::\U$request"};
        my $res = $method->($url, @args);
        print Apache::TestRequest::to_string($res);
    }
}

sub opt_clean {
    my($self) = @_;
    my $test_config = $self->{test_config};
    $test_config->server->stop;
    $test_config->clean;
    1;
}

sub opt_ping {
    my($self) = @_;

    my $test_config = $self->{test_config};
    my $server = $test_config->server;
    my $pid = $server->ping;
    my $name = $server->{name};

    if ($pid) {
        if ($pid == -1) {
            error "port $test_config->{vars}->{port} is in use, ".
                  "but cannot determine server pid";
        }
        else {
            my $version = $server->{version};
            warning "server $name running (pid=$pid, version=$version)";
        }
        return 1;
    }

    warning "no server is running on $name";
    return 1; #means call exit()
}

sub test_inc {
    map { "$_/Apache-Test/lib" } qw(. ..);
}

sub set_perl5lib {
    $ENV{PERL5LIB} = join $Config{path_sep}, shift->test_inc();
}

sub opt_debug {
    my $self = shift;
    my $server = $self->{server};

    my $opts = $self->{opts};
    my $debug_opts = {};

    for (qw(debugger breakpoint)) {
        $debug_opts->{$_} = $opts->{$_};
    }

    if ($opts->{debugger}) {
        if ($opts->{debugger} eq 'perl') {
            $opts->{'run-tests'} = 1;
            $self->start; #if not already running
            $self->set_perl5lib;
            system $^X, '-MApache::TestPerlDB', '-d', @{ $self->{tests} };
            $self->stop;
            return 1;
        }
        elsif ($opts->{debugger} =~ s/^lwp[=:]?//) {
            $ENV{APACHE_TEST_DEBUG_LWP} = $opts->{debugger} || 1;
            $opts->{verbose} = 1;
            return 0;
        }
    }

    $server->stop;
    $server->start_debugger($debug_opts);
    1;
}

sub opt_help {
    my $self = shift;

    print <<EOM;
usage: TEST [options ...]
   where options include:
EOM

    for (sort keys %usage){
        printf "   -%-16s %s\n", $_, $usage{$_};
    }

    print "\n   configuration options:\n";

    Apache::TestConfig->usage;
    1;
}

1;
