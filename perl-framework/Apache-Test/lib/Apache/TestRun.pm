package Apache::TestRun;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();
use Apache::TestRequest ();
use Apache::TestHarness ();

use File::Spec::Functions qw(catfile);
use Getopt::Long qw(GetOptions);

my @std_run      = qw(start-httpd run-tests stop-httpd);
my @others       = qw(verbose configure clean help ping);
my @flag_opts    = (@std_run, @others);
my @list_opts    = qw(preamble postamble);
my @hash_opts    = qw(header);
my @exit_opts    = qw(clean help ping debug);
my @request_opts = qw(get head post);

my %usage = (
   'start-httpd' => 'start the test server',
   'run-tests'   => 'run the tests',
   'stop-httpd'  => 'stop the test server',
   'verbose'     => 'verbose output',
   'configure'   => 'force regeneration of httpd.conf',
   'clean'       => 'remove all generated test files',
   'help'        => 'display this message',
   'preamble'    => 'config to add at the beginning of httpd.conf',
   'postamble'   => 'config to add at the end of httpd.conf',
   'ping'        => 'test if server is running or port in use',
   'debug'       => 'start server under debugger (e.g. gdb)',
   'header'      => "add headers to (".join('|', @request_opts).") request",
   (map { $_, "\U$_\E url" } @request_opts),
);

sub new {
    my $class = shift;
    bless {
        tests => [],
        @_,
    }, $class;
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

    #default HEAD|GET to /
    for (my $i = 0; $i < @args; $i++) {
        if ($args[$i] =~ /^-(get|head)/) {
            unless ($args[$i+1] and $args[$i+1] =~ m:^/:) {
                splice @args, $i+1, 0, '/';
            }
            last;
        }
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

    GetOptions(\%opts, @flag_opts, @exit_opts,
               (map "$_=s", @request_opts),
               (map { ("$_=s", $vopts{$_} ||= []) } @list_opts),
               (map { ("$_=s", $vopts{$_} ||= {}) } @hash_opts));

    $opts{$_} = $vopts{$_} for keys %vopts;

    #force regeneration of httpd.conf if commandline args want to modify it
    $opts{configure} ||=
      (grep { $opts{$_}->[0] } qw(preamble postamble)) ||
        @ARGV || $self->passenv() || (! -e 'conf/httpd.conf');

    while (my($key, $val) = splice @ARGV, 0, 2) {
       $conf_opts{lc $key} = $val;
    }

    if ($opts{configure}) {
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

    unless (grep { $opts->{$_} } @std_run, @request_opts) {
        if (@$tests && $self->{server}->ping) {
            #if certain tests are specified and server is running, dont restart
            $opts->{'run-tests'} = 1;
        }
        else {
            #default is server-server run-tests stop-server
            $opts->{$_} = 1 for @std_run;
        }
    }
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
            print "\ncaught SIGINT\n";
            exit;
        }
        print "\nhalting tests\n";
        $server->stop if $opts->{'start-httpd'};
        exit;
    };
}

sub configure_opts {
    my $self = shift;

    my($test_config, $opts) = ($self->{test_config}, $self->{opts});

    my $preamble  = sub { shift->preamble($opts->{preamble}) };
    my $postamble = sub { shift->postamble($opts->{postamble}) };

    $test_config->preamble_register($preamble);
    $test_config->postamble_register($postamble);
}

sub configure {
    my $self = shift;

    $self->configure_opts;

    my $test_config = $self->{test_config};
    $test_config->generate_httpd_conf;
    $test_config->save;
}

sub try_exit_opts {
    my $self = shift;

    for (@exit_opts) {
        next unless $self->{opts}->{$_};
        my $method = "opt_$_";
        $self->$method();
        exit;
    }

    if ($self->{opts}->{'stop-httpd'}) {
        $self->{server}->stop;
        exit;
    }
}

sub start {
    my $self = shift;

    my $test_config = $self->{test_config};

    unless ($test_config->{vars}->{httpd}) {
        print "no test server configured, please specify an httpd or ";
        print $test_config->{MP_APXS} ?
          "an apxs other than $test_config->{MP_APXS}" : "apxs";
        print "\nor put either in your PATH\n";
        exit 1;
    }

    if ($self->{opts}->{'start-httpd'}) {
        exit 1 unless $self->{server}->start;
    }
}

sub run_tests {
    my $self = shift;

    my $test_opts = {
        verbose => $self->{opts}->{verbose},
        tests   => $self->{tests},
    };

    if (grep { $self->{opts}->{$_} } @request_opts) {
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

    $self->try_exit_opts;

    $self->configure if $self->{conf_opts}->{save}; #cache generated config

    $self->default_run_opts;

    $self->start;

    $self->run_tests;

    $self->stop;
}

sub run_request {
    my($test_config, $opts) = @_;

    my @args = %{ $opts->{header} };
    my $wanted_args = Apache::TestRequest::wanted_args();

    while (my($key, $val) = each %{ $test_config->{vars} }) {
        next unless $wanted_args->{$key};
        push @args, $key, $val;
    }

    for (@request_opts) {
        next unless $opts->{$_};
        my $method = \&{"Apache::TestRequest::\U$_"};
        my $res = $method->($opts->{$_}, @args);
        print Apache::TestRequest::to_string($res);
    }
}

sub opt_clean {
    my($self) = @_;
    my $test_config = $self->{test_config};
    $test_config->server->stop;
    $test_config->clean;
}

sub opt_ping {
    my($self) = @_;

    my $test_config = $self->{test_config};
    my $server = $test_config->server;
    my $pid = $server->ping;
    my $name = $server->{name};

    if ($pid) {
        if ($pid == -1) {
            print "port $test_config->{vars}->{port} is in use, ",
                  "but cannot determine server pid\n";
        }
        else {
            my $version = $server->{version};
            print "server $name running (pid=$pid, version=$version)\n";
        }
        return;
    }

    print "no server is running on $name\n";
}

sub opt_debug {
    my $self = shift;
    my $server = $self->{server};
    $server->stop;
    $server->start_debugger;
}

sub opt_help {
    my $self = shift;

    print <<EOM;
usage: TEST [options ...]
   where options include:
EOM

    while (my($key, $val) = each %usage) {
        printf "   -%-16s %s\n", $key, $val;
    }

    print "\n   configuration options:\n";

    Apache::TestConfig->usage;
}

1;
