package Apache::TestServer;

use strict;
use warnings FATAL => 'all';

use Socket ();
use File::Spec::Functions qw(catfile);

use Apache::TestTrace;
use Apache::TestConfig ();

# some debuggers use the same syntax as others, so we reuse the same
# code by using the following mapping
my %debuggers =
    (
     gdb => 'gdb',
     ddd => 'gdb',
    );

sub trace {
    shift->{config}->trace(@_);
}

sub new {
    my $class = shift;
    my $config = shift;

    my $self = bless {
        config => $config || Apache::TestConfig->thaw,
    }, $class;

    $self->{name} = join ':',
      map { $self->{config}->{vars}->{$_} } qw(servername port);

    $self->{port_counter} = $self->{config}->{vars}->{port};

    $self->{version} = $self->{config}->httpd_version || '';
    ($self->{rev}) = $self->{version} =~ m:^Apache/(\d)\.:;
    $self->{rev} ||= 2;

    $self;
}

sub version_of {
    my($self, $thing) = @_;
    $thing->{$self->{rev}};
}

sub clean {
    my $self = shift;

    my $dir = $self->{config}->{vars}->{t_logs};

    for (qw(error_log access_log httpd.pid)) {
        my $file = catfile $dir, $_;
        if (unlink $file) {
            $self->trace("unlink $file");
        }
    }
}

sub pid_file {
    my $self = shift;
    catfile $self->{config}->{vars}->{t_logs}, 'httpd.pid';
}

sub args {
    my $self = shift;
    my $vars = $self->{config}->{vars};
    "-d $vars->{serverroot} -f $vars->{t_conf_file}";
}

my %one_process = (1 => '-X', 2 => '-DONE_PROCESS');

sub start_cmd {
    my $self = shift;
    #XXX: threaded mpm does not respond to SIGTERM with -DONE_PROCESS
    my $one = $self->{rev} == 1 ? '-X' : '';
    my $args = $self->args;
    my $dversion = "-DAPACHE$self->{rev}"; #for .conf version conditionals
    return "$self->{config}->{vars}->{httpd} $dversion $one $args";
}

sub start_gdb {
    my $self = shift;
    my $opts = shift;

    my $debugger    = $opts->{debugger};
    my @breakpoints = @{ $opts->{breakpoint} || [] };
    my $config      = $self->{config};
    my $args        = $self->args;
    my $one_process = $self->version_of(\%one_process);

    my $file = catfile $config->{vars}->{serverroot}, '.gdb-test-start';
    my $fh   = $config->genfile($file, 1);

    if (@breakpoints) {
        print $fh "b ap_run_pre_config\n";
        print $fh "run $one_process $args\n";
        print $fh "finish\n";
        for (@breakpoints) {
            print $fh "b $_\n"
        }
        print $fh "continue\n";
    }
    else {
        print $fh "run $one_process $args\n";
    }
    close $fh;

    my $command;
    if ($debugger eq 'ddd') {
        $command = qq{ddd --gdb --debugger "gdb -command $file" $config->{vars}->{httpd}};
    }
    else {
        $command = "gdb $config->{vars}->{httpd} -command $file";
    }

    debug  $command;
    system $command;

    unlink $file;
}

sub start_debugger {
    my $self = shift;
    my $opts = shift;

    $opts->{debugger} ||= $ENV{MP_DEBUGGER} || 'gdb';

    unless ($debuggers{ $opts->{debugger} }) {
        error "$opts->{debugger} is not a supported debugger",
              "These are the supported debuggers: ".
              join ", ", sort keys %debuggers;
        die("\n");
    }

    my $method = "start_".$debuggers{ $opts->{debugger} };
    $self->$method($opts);
}

sub pid {
    my $self = shift;
    my $file = $self->pid_file;
    open my $fh, $file or do {
        return 0;
    };
    chomp(my $pid = <$fh>);
    $pid;
}

sub select_port {
    my $self = shift;

    my $max_tries = 100; #XXX

    while (! $self->port_available(++$self->{port_counter})) {
        return 0 if --$max_tries <= 0;
    }

    return $self->{port_counter};
}

sub port_available {
    my $self = shift;
    my $port = shift || $self->{config}->{vars}->{port};
    local *S;

    my $proto = getprotobyname('tcp');

    socket(S, Socket::PF_INET(),
           Socket::SOCK_STREAM(), $proto) || die "socket: $!";
    setsockopt(S, Socket::SOL_SOCKET(),
               Socket::SO_REUSEADDR(),
               pack("l", 1)) || die "setsockopt: $!";

    if (bind(S, Socket::sockaddr_in($port, Socket::INADDR_ANY()))) {
        close S;
        return 1;
    }
    else {
        return 0;
    }
}

=head2 stop()

attempt to stop the server.

returns:

  on success: $pid of the server
  on failure: -1

=cut

sub stop {
    my $self = shift;
    my $aborted = shift;

    my $pid = 0;
    my $tries = 3;
    my $tried_kill = 0;

    my $port = $self->{config}->{vars}->{port};

    while ($self->ping) {
        #my $state = $tried_kill ? "still" : "already";
        #print "Port $port $state in use\n";

        if ($pid = $self->pid and !$tried_kill++) {
            if (kill TERM => $pid) {
                warning "server $self->{name} shutdown (pid=$pid)";
                sleep 1;

                for (1..4) {
                    if (! $self->ping) {
                        return $pid if $_ == 1;
                        last;
                    }
                    if ($_ == 1) {
                        warning "port $port still in use...";
                    }
                    else {
                        print "...";
                    }
                    sleep $_;
                }

                if ($self->ping) {
                    error "\nserver was shutdown but port $port ".
                          "is still in use, please shutdown the service ".
                          "using this port or select another port ".
                          "for the tests";
                }
                else {
                    print "done\n";
                }
            }
            else {
                error "kill $pid failed: $!";
            }
        }
        else {
            error "port $port is in use, ".
                  "cannot determine server pid to shutdown";
            return -1;
        }

        if (--$tries <= 0) {
            error "cannot shutdown server on Port $port, ".
                  "please shutdown manually";
            return -1;
        }
    }

    return $pid;
}

sub ping {
    my $self = shift;
    my $pid = $self->pid;

    if ($pid and kill 0, $pid) {
        return $pid;
    }
    elsif (! $self->port_available) {
        return -1;
    }

    return 0;
}

sub failed_msg {
    my $self = shift;
    my($log, $rlog) = $self->{config}->error_log;
    my $log_file_info = -e $log ?
        "please examine $rlog" :
        "$rlog wasn't created, start the server in the debug mode";
    error "@_ ($log_file_info)";
}

sub start {
    my $self = shift;
    my $old_pid = $self->stop;
    my $cmd = $self->start_cmd;
    my $config = $self->{config};
    my $vars = $config->{vars};
    my $httpd = $vars->{httpd} || 'unknown';

    if ($old_pid == -1) {
        return 0;
    }

    local $| = 1;

    unless (-x $httpd) {
        my $why = -e $httpd ? "is not executable" : "does not exist";
        error "cannot start server: httpd ($httpd) $why";
        return 0;
    }

    print "$cmd\n";
    system "$cmd &";

    while ($old_pid and $old_pid == $self->pid) {
        warning "old pid file ($old_pid) still exists\n";
        sleep 1;
    }

    my $version = $self->{version};
    my $mpm = $config->{mpm} || "";
    $mpm = "($mpm MPM)" if $mpm;
    print "using $version $mpm\n";

    my $tries = 5;

    for (1..$tries) {
        my $pid = $self->pid;
        if ($pid) {
            if($_ > 1) {
                print "ok\n";
            }
        }
        else {
            if ($_ == 1) {
                print "waiting for server to warm up...";
            }
            elsif ($_ >= $tries) {
                print "giving up\n";
            }
            else {
                print "...";
            }
            sleep $_;
            next;
        }
        last;
    }

    if (my $pid = $self->pid) {
        print "server $self->{name} started (pid=$pid)\n";
        while (my($module, $cfg) = each %{ $config->{vhosts} }) {
            print "server $cfg->{name} listening ($module)\n",
        }
        if ($config->{modules}->{'mod_ssl.c'} and
            !$self->port_available($vars->{sslport})) {
            my $hostport = join ':', $vars->{servername}, $vars->{sslport};
            print "server $hostport listening (mod_ssl)\n";
        }
    }
    else {
        $self->failed_msg("server failed to start!");
        return 0;
    }

    my $server_up = sub {
        local $SIG{__WARN__} = sub {}; #avoid "cannot connect ..." warnings
        $config->http_raw_get('/index.html');
    };

    if ($server_up->()) {
        return 1;
    }
    else {
        warning "still waiting for server to warm up...";
        sleep 1;
    }

    for my $try (1..$tries) {
        if ($server_up->()) {
            print "ok\n";
            return 1;
        }
        elsif ($try >= $tries) {
            print "giving up\n";
        }
        else {
            print "...";
            sleep $try;
        }
    }

    $self->failed_msg("\nfailed to start server!");
    return 0;
}

1;
