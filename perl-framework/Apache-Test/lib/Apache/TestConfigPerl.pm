package Apache::TestConfig; #not TestConfigPerl on purpose

#things specific to mod_perl

use strict;
use warnings FATAL => 'all';
use File::Spec::Functions qw(catfile splitdir abs2rel);
use File::Find qw(finddepth);

my %libmodperl  = (1 => 'libperl.so', 2 => 'libmodperl.so');

sub configure_libmodperl {
    my $self = shift;

    my $server = $self->{server};
    my $libname = $server->version_of(\%libmodperl);

    if ($server->{rev} >= 2) {
        if (my $build_config = $self->build_config()) {
            $libname = $build_config->{MODPERL_LIB_SHARED}
        }
    }

    my $vars = $self->{vars};

    $vars->{libmodperl} ||= $self->find_apache_module($libname);

    my $cfg;

    if (-e $vars->{libmodperl}) {
        $cfg = {LoadModule => qq(perl_module "$vars->{libmodperl}")};
    }
    else {
        my $msg = "unable to locate $libname\n";
        $cfg = "#$msg";
        $self->trace($msg);
    }
    $self->preamble(IfModule => '!mod_perl.c', $cfg);
}

sub configure_inc {
    my $self = shift;

    my $top = $self->{vars}->{top_dir};

    my $inc = $self->{inc};
    my @trys = (catfile($top, 'lib'),
                catfile($top, qw(blib lib)),
                catfile($top, qw(blib arch)));

    for (@trys) {
        push @$inc, $_ if -d $_;
    }
}

sub write_pm_test {
    my($self, $pm, $base, $sub) = @_;

    my $dir = catfile $self->{vars}->{t_dir}, $base;
    my $t = catfile $dir, "$sub.t";
    return if -e $t;

    $self->gendir($dir);
    my $fh = $self->genfile($t, 1);

    print $fh <<EOF;
use Apache::TestConfig ();
print Apache::TestConfig->thaw->http_raw_get("/$pm");
EOF

    close $fh or die "close $t: $!";
}


my %startup_pl = (1 => 'PerlRequire', 2 => 'PerlSwitches');

sub startup_pl_code {
    my $self = shift;
    my $serverroot = $self->{vars}->{serverroot};

    return <<"EOF";
BEGIN {
    use lib '$serverroot';
    for my \$file (qw(modperl_inc.pl modperl_extra.pl)) {
        eval { require "conf/\$file" };
    }
}

1;
EOF
}

sub configure_startup_pl {
    my $self = shift;

    #for 2.0 we could just use PerlSwitches -Mlib=...
    #but this will work for both 2.0 and 1.xx
    if (my $inc = $self->{inc}) {
        my $include_pl = catfile $self->{vars}->{t_conf}, 'modperl_inc.pl';
        my $fh = $self->genfile($include_pl, 1);
        for (@$inc) {
            print $fh "use lib '$_';\n";
        }
        print $fh "1;\n";
    }

    if ($self->server->{rev} >= 2) {
        $self->postamble(PerlSwitches => "-Mlib=$self->{vars}->{serverroot}");
    }

    my $startup_pl = catfile $self->{vars}->{t_conf}, 'modperl_startup.pl';

    unless (-e $startup_pl) {
        my $fh = $self->genfile($startup_pl, 1);
        print $fh $self->startup_pl_code;
        close $fh;
    }

    my $directive = $self->server->version_of(\%startup_pl);
    $self->postamble($directive => $startup_pl);
}

my %sethandler_modperl = (1 => 'perl-script', 2 => 'modperl');

my %add_hook_config = (
    Response => sub { my($self, $module, $args) = @_;
                      push @$args,
                        SetHandler =>
                          $self->server->version_of(\%sethandler_modperl) },
    ProcessConnection => sub { my($self, $module, $args) = @_;
                               my $port = $self->new_vhost($module);
                               $self->postamble(Listen => $port); },
);

my %container_config = (
    ProcessConnection => \&vhost_container,
);

sub location_container {
    my($self, $module) = @_;
    Location => "/$module";
}

sub vhost_container {
    my($self, $module) = @_;
    my $port = $self->{vhosts}->{$module}->{port};
    VirtualHost => "_default_:$port";
}

sub new_vhost {
    my($self, $module) = @_;

    my $port       = $self->server->select_port;
    my $servername = $self->{vars}->{servername};
    my $vhost      = $self->{vhosts}->{$module} = {};

    $vhost->{port}       = $port;
    $vhost->{servername} = $servername;
    $vhost->{name}       = join ':', $servername, $port;
    $vhost->{hostport}   = $self->hostport($vhost);

    $port;
}

my %outside_container = map { $_, 1 } qw{
Alias AliasMatch AddType
PerlChildInitHandler PerlTransHandler PerlPostReadRequestHandler
};

#test .pm's can have configuration after the __DATA__ token
sub add_module_config {
    my($self, $module, $args) = @_;
    open(my $fh, $module) or return;

    while (<$fh>) {
        last if /^__(DATA|END)__/;
    }

    while (<$fh>) {
        next unless /\S+/;
        chomp;
        $self->replace;
        my($directive, $rest) = split /\s+/, $_, 2;
        if ($outside_container{$directive}) {
            $self->postamble($directive => $rest);
        }
        elsif ($directive =~ m/^<(\w+)/) {
            if ($directive eq '<VirtualHost') {
                $rest =~ s/>$//;
                my $port = $self->new_vhost($rest);
                $self->postamble(Listen => $port);
                $rest = "_default_:$port>";
            }
            $self->postamble($directive => $rest);
            my $end = "</$1>";
            while (<$fh>) {
                $self->replace;
                $self->postamble($_);
                last if m:^\Q$end:;
            }
        }
        else {
            push @$args, $directive, $rest;
        }
    }
}

#the idea for each group:
# Response: there will be many of these, mostly modules to test the API
#           that plan tests => ... and output with ok()
#           the naming allows grouping, making it easier to run an
#           individual set of tests, e.g. t/TEST t/apr
#           the PerlResponseHandler and SetHandler modperl is auto-configured
# Hooks:    for testing the simpler Perl*Handlers
#           auto-generates the Perl*Handler config
# Protocol: protocol modules need their own port/vhost to listen on

#@INC is auto-modified so each test .pm can be found
#modules can add their own configuration using __DATA__

my %hooks = map { $_, ucfirst $_ }
  qw(trans access authen authz type fixup log);
$hooks{Protocol} = 'ProcessConnection';
$hooks{Filter}   = 'OutputFilter';

sub configure_pm_tests {
    my $self = shift;

    for my $subdir (qw(Response Protocol Hooks Filter)) {
        my $dir = catfile $self->{vars}->{t_dir}, lc $subdir;
        next unless -d $dir;

        push @{ $self->{inc} }, $dir;

        finddepth(sub {
            return unless /\.pm$/;
            my @args;

            my $pm = $_;
            my $module = catfile $File::Find::dir, $pm;
            $self->add_module_config($module, \@args);
            $module = abs2rel $module, $dir;
            $module =~ s,\.pm$,,;
            $module = join '::', splitdir $module;

            my($base, $sub) =
              map { s/^test//i; $_ } split '::', $module;

            my $hook = $hooks{$sub} || $hooks{$subdir} || $subdir;

            if ($hook eq 'OutputFilter' and $pm =~ /^i/) {
                #XXX: tmp hack
                $hook = 'InputFilter';
            }

            my $handler = join $hook, qw(Perl Handler);

            if ($self->server->{rev} < 2 and lc($hook) eq 'response') {
                $handler =~ s/response//i; #s/PerlResponseHandler/PerlHandler/
            }

            $self->trace("configuring $module");

            if (my $cv = $add_hook_config{$hook}) {
                $self->$cv($module, \@args);
            }

            my $container = $container_config{$hook} || \&location_container;
            my @handler_cfg = ($handler => $module);

            if ($outside_container{$handler}) {
                $self->postamble(@handler_cfg);
            }
            else {
                push @args, @handler_cfg;
            }

            $self->postamble($self->$container($module),
                             { @args }) if @args;

            $self->write_pm_test($module, lc $base, lc $sub);
        }, $dir);
    }
}

1;
