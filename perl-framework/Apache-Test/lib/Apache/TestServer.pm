package Apache::TestServer;

use strict;
use warnings FATAL => 'all';

use Socket ();
use File::Spec::Functions qw(catfile);

use Apache::TestConfig ();

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
    return "$self->{config}->{vars}->{httpd} $one $args";
}

sub start_gdb {
    my $self = shift;

    my $config = $self->{config};
    my $args = $self->args;
    my $one_process = $self->version_of(\%one_process);

    my $file = catfile $config->{vars}->{serverroot}, '.gdb-test-start';
    my $fh = $config->genfile($file, 1);
    print $fh "run $one_process $args";
    close $fh;

    system "gdb $config->{vars}->{httpd} -command $file";

    unlink $file;
}

sub start_debugger {
    shift->start_gdb; #XXX support dbx and others
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
                print "server $self->{name} shutdown (pid=$pid)\n";
                sleep 1;

                for (1..4) {
                    if (! $self->ping) {
                        return $pid if $_ == 1;
                        last;
                    }
                    if ($_ == 1) {
                        print "port $port still in use...";
                    }
                    else {
                        print "...";
                    }
                    sleep $_;
                }

                if ($self->ping) {
                    print "\nserver was shutdown but port $port ",
                          "is still in use, please shutdown the service ",
                          "using this port or select another port ",
                          "for the tests\n";
                }
                else {
                    print "done\n";
                }
            }
            else {
                print "kill $pid failed: $!\n";
            }
        }
        else {
            print "port $port is in use, ",
                  "cannot determine server pid to shutdown\n";
            return -1;
        }

        if (--$tries <= 0) {
            print "cannot shutdown server on Port $port, ",
                  "please shutdown manually\n";
            return -1;
        }
    }

    $self->clean unless $aborted;

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
    my $log = $self->{config}->error_log(1);
    print "@_ (please examine $log)\n";
}

sub start {
    my $self = shift;
    my $old_pid = $self->stop;
    my $cmd = $self->start_cmd;
    my $httpd = $self->{config}->{vars}->{httpd} || 'unknown';

    if ($old_pid == -1) {
        return 0;
    }

    local $| = 1;

    unless (-x $httpd) {
        my $why = -e $httpd ? "is not executable" : "does not exist";
        print "cannot start server: httpd ($httpd) $why\n";
        return 0;
    }

    print "$cmd\n";
    system "$cmd &";

    while ($old_pid and $old_pid == $self->pid) {
        print "old pid file ($old_pid) still exists\n";
        sleep 1;
    }

    my $tries = 6;

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
        my $version = $self->{version};
        print "server $self->{name} started (pid=$pid, version=$version)\n";
        while (my($module, $cfg) = each %{ $self->{config}->{vhosts} }) {
            print "server $cfg->{name} listening ($module)\n",
        }
    }
    else {
        $self->failed_msg("server failed to start!");
        return 0;
    }

    my $server_up = sub { $self->{config}->http_raw_get('/index.html') };

    if ($server_up->()) {
        return 1;
    }
    else {
        print "still waiting for server to warm up...";
        sleep 1;
    }

    for (1..$tries) {
        if ($server_up->()) {
            print "ok\n";
            return 1;
        }
        elsif ($_ >= $tries) {
            print "giving up\n";
        }
        else {
            print "...";
            sleep $_;
        }
    }

    $self->failed_msg("\nfailed to start server!");
    return 0;
}

1;
