package Apache::TestConfig; #not TestConfigPerl on purpose

#things specific to mod_perl

use strict;
use warnings FATAL => 'all';
use File::Spec::Functions qw(catfile splitdir abs2rel);
use File::Find qw(finddepth);
use Apache::TestTrace;
use Apache::TestRequest;
use Config;

my %libmodperl  = (1 => 'libperl.so', 2 => 'mod_perl.so');

sub configure_libmodperl {
    my $self = shift;

    my $server = $self->{server};
    my $libname = $server->version_of(\%libmodperl);
    my $vars = $self->{vars};

    # XXX: $server->{rev} could be set to 2 as a fallback, even when
    # the wanted version is 1. So check that we use mod_perl 2
    if ($server->{rev} >= 2 && IS_MOD_PERL_2) {
        if (my $build_config = $self->modperl_build_config()) {
            $libname = $build_config->{MODPERL_LIB_SHARED};
            $vars->{libmodperl} ||= $self->find_apache_module($libname);
            # XXX: we have a problem with several perl trees pointing
            # to the same httpd tree. So it's possible that we
            # configure the test suite to run with mod_perl.so built
            # against perl which it wasn't built with. Should we use
            # something like ldd to check the match?
        }
        else {
            # XXX: can we test whether mod_perl was linked statically
            # so we don't need to preload it
            # if (!linked statically) {
            #     die "can't find mod_perl built for perl version $]"
            # }
            error "can't find mod_perl.so built for perl version $]";
        }
        # don't use find_apache_module or we may end up with the wrong
        # shared object, built against different perl
    }
    else {
        # mod_perl 1.0
        $vars->{libmodperl} ||= $self->find_apache_module($libname);
        # XXX: how do we find out whether we have a static or dynamic
        # mod_perl build? die if its dynamic and can't find the module
    }

    my $cfg = '';

    if ($vars->{libmodperl} && -e $vars->{libmodperl}) {
        if (Apache::TestConfig::WIN32) {
            my $lib = "$Config{installbin}\\$Config{libperl}";
            $lib =~ s/lib$/dll/;
            $cfg = 'LoadFile ' . qq("$lib"\n) if -e $lib;
	}
        $cfg .= 'LoadModule ' . qq(perl_module "$vars->{libmodperl}"\n);
    }
    else {
        my $msg = "unable to locate $libname (could be a static build)\n";
        $cfg = "#$msg";
        debug $msg;
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

    # spec: If PERL5LIB is defined, PERLLIB is not used.
    for (qw(PERL5LIB PERLLIB)) {
        next unless exists $ENV{$_};
        push @$inc, split /$Config{path_sep}/, $ENV{$_};
        last;
    }

    # enable live testing of the Apache-Test dev modules if they are
    # located at the project's root dir
    my $apache_test_dev_dir = catfile($top, 'Apache-Test', 'lib');
    unshift @$inc, $apache_test_dev_dir if -d $apache_test_dev_dir;
}

sub write_pm_test {
    my($self, $module, $base, $sub) = @_;

    my $dir = catfile $self->{vars}->{t_dir}, $base;
    my $t = catfile $dir, "$sub.t";
    return if -e $t;

    $self->gendir($dir);
    my $fh = $self->genfile($t);

    my $path = Apache::TestRequest::module2path($module);

    print $fh <<EOF;
use Apache::TestRequest 'GET_BODY_ASSERT';
print GET_BODY_ASSERT "/$path";
EOF

    close $fh or die "close $t: $!";
}

sub startup_pl_code {
    my $self = shift;
    my $serverroot = $self->{vars}->{serverroot};

    return <<"EOF";
BEGIN {
    use lib '$serverroot';
    for my \$file (qw(modperl_inc.pl modperl_extra.pl)) {
        eval { require "conf/\$file" } or
            die if grep { -e "\$_/conf/\$file" } \@INC;
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
        my $fh = $self->genfile($include_pl);
        # make sure that the dev libs come before blib
        for (reverse @$inc) {
            print $fh "use lib '$_';\n";
        }
        print $fh "1;\n";
    }

    if ($self->server->{rev} >= 2) {
        $self->postamble(PerlSwitches => "-Mlib=$self->{vars}->{serverroot}");
    }

    my $startup_pl = catfile $self->{vars}->{t_conf}, 'modperl_startup.pl';

    unless (-e $startup_pl) {
        my $fh = $self->genfile($startup_pl);
        print $fh $self->startup_pl_code;
        close $fh;
    }

    $self->postamble(PerlRequire => $startup_pl);
}

my %sethandler_modperl = (1 => 'perl-script', 2 => 'modperl');

sub set_handler {
    my($self, $module, $args) = @_;
    return if grep { $_ eq 'SetHandler' } @$args;

    push @$args,
      SetHandler =>
        $self->server->version_of(\%sethandler_modperl);
}

sub set_connection_handler {
    my($self, $module, $args) = @_;
    my $port = $self->new_vhost($module);
    $self->postamble(Listen => $port);
}

my %add_hook_config = (
    Response          => \&set_handler,
    ProcessConnection => \&set_connection_handler,
    PreConnection     => \&set_connection_handler,
);

my %container_config = (
    ProcessConnection => \&vhost_container,
    PreConnection     => \&vhost_container,
);

sub location_container {
    my($self, $module) = @_;
    my $path = Apache::TestRequest::module2path($module);
    Location => "/$path";
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
    $vhost->{hostport}   = $self->hostport($vhost, $module);

    $port;
}

my %outside_container = map { $_, 1 } qw{
Alias AliasMatch AddType
PerlChildInitHandler PerlTransHandler PerlPostReadRequestHandler
PerlSwitches PerlRequire PerlModule
};

my %strip_tags = map { $_ => 1} qw(base noautoconfig);

#test .pm's can have configuration after the __DATA__ token
sub add_module_config {
    my($self, $module, $args) = @_;
    my $fh = Symbol::gensym();
    open($fh, $module) or return;

    while (<$fh>) {
        last if /^(__(DATA|END)__|\#if CONFIG_FOR_HTTPD_TEST)/;
    }

    my %directives;

    while (<$fh>) {
        last if /^\#endif/; #for .c modules
        next unless /\S+/;
        chomp;
        s/^\s+//;
        $self->replace;
        if (/^#/) {
            # preserve comments
            $self->postamble($_);
            next;
        }
        my($directive, $rest) = split /\s+/, $_, 2;
        $directives{$directive}++ unless $directive =~ /^</;
        $rest = '' unless defined $rest;

        if ($outside_container{$directive}) {
            $self->postamble($directive => $rest);
        }
        elsif ($directive =~ /IfModule/) {
            $self->postamble($_);
        }
        elsif ($directive =~ m/^<(\w+)/) {
            # strip special container directives like <Base> and </Base>
            my $strip_container = exists $strip_tags{lc $1} ? 1 : 0;

            $directives{noautoconfig}++ if lc($1) eq 'noautoconfig';

            my $indent = '';
            $self->process_container($_, $fh, lc($1),
                                     $strip_container, $indent);
        }
        else {
            push @$args, $directive, $rest;
        }
    }

    \%directives;
}


# recursively process the directives including nested containers,
# re-indent 4 and ucfirst the closing tags letter
sub process_container {
    my($self, $first_line, $fh, $directive, $strip_container, $indent) = @_;

    my $new_indent = $indent;

    unless ($strip_container) {
        $new_indent .= "    ";

        local $_ = $first_line;
        s/^\s*//;
        $self->replace;

        if (/<VirtualHost/) {
            $self->process_vhost_open_tag($_, $indent);
        }
        else {
            $self->postamble($indent . $_);
        }
    }

    $self->process_container_remainder($fh, $directive, $new_indent);

    unless ($strip_container) {
        $self->postamble($indent . "</\u$directive>");
    }

}


# processes the body of the container without the last line, including
# the end tag
sub process_container_remainder {
    my($self, $fh, $directive, $indent) = @_;

    my $end_tag = "</$directive>";

    while (<$fh>) {
        chomp;
        last if m|^\s*\Q$end_tag|i;
        s/^\s*//;
        $self->replace;

        if (m/^\s*<(\w+)/) {
            $self->process_container($_, $fh, $1, 0, $indent);
        }
        else {
            $self->postamble($indent . $_);
        }
    }
}

# does the necessary processing to create a vhost container header
sub process_vhost_open_tag {
    my($self, $line, $indent) = @_;

    my $cfg = $self->parse_vhost($line);

    if ($cfg) {
        my $port = $cfg->{port};
        $cfg->{out_postamble}->();
        $self->postamble("$indent<VirtualHost _default_:$port>");
        $cfg->{in_postamble}->();
    } else {
        $self->postamble("$indent$line");
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
    qw(init trans headerparser access authen authz type fixup log);
$hooks{Protocol} = 'ProcessConnection';
$hooks{Filter}   = 'OutputFilter';

my @extra_subdirs = qw(Response Protocol PreConnection Hooks Filter);

# add the subdirs to @INC early, in case mod_perl is started earlier
sub configure_pm_tests_inc {
    my $self = shift;
    for my $subdir (@extra_subdirs) {
        my $dir = catfile $self->{vars}->{t_dir}, lc $subdir;
        next unless -d $dir;

        push @{ $self->{inc} }, $dir;
    }
}

# @status fields
use constant APACHE_TEST_CONFIGURE    => 0;
use constant APACHE_TEST_CONFIG_ORDER => 1;

sub configure_pm_tests_pick {
    my($self, $entries) = @_;

    for my $subdir (@extra_subdirs) {
        my $dir = catfile $self->{vars}->{t_dir}, lc $subdir;
        next unless -d $dir;

        finddepth(sub {
            return unless /\.pm$/;

            my $file = catfile $File::Find::dir, $_;
            my $module = abs2rel $file, $dir;
            my $status = $self->run_apache_test_config_scan($file);
            push @$entries, [$file, $module, $subdir, $status];
        }, $dir);
    }
}


# a simple numerical order is performed and configuration sections are
# inserted using that order. If the test package specifies no special
# token that matches /APACHE_TEST_CONFIG_ORDER\s+([+-]?\d+)/ anywhere
# in the file, 0 is assigned as its order. If the token is specified,
# config section with negative values will be inserted first, with
# positive last. By using different values you can arrange for the
# test configuration sections to be inserted in any desired order
sub configure_pm_tests_sort {
    my($self, $entries) = @_;

    @$entries = sort {
        $a->[3]->[APACHE_TEST_CONFIG_ORDER] <=>
        $b->[3]->[APACHE_TEST_CONFIG_ORDER]
    } @$entries;

}

sub configure_pm_tests {
    my $self = shift;

    # since server wasn't started yet, the modules in blib under
    # Apache2 can't be seen. So we must load Apache2.pm, without which
    # run_apache_test_config might fail to require modules
    require mod_perl;
    if ($mod_perl::VERSION > 1.99) {
        require Apache2;
    }

    my @entries = ();
    $self->configure_pm_tests_pick(\@entries);
    $self->configure_pm_tests_sort(\@entries);

    for my $entry (@entries) {
        my ($file, $module, $subdir, $status) = @$entry;
        my @args = ();

        my $directives = $self->add_module_config($file, \@args);
        $module =~ s,\.pm$,,;
        $module =~ s/^[a-z]://i; #strip drive if any
        $module = join '::', splitdir $module;

        $self->run_apache_test_configure($file, $module, $status);

        my($base, $sub) =
            map { s/^test//i; $_ } split '::', $module;

        my $hook = ($subdir eq 'Hooks' ? $hooks{$sub} : '')
            || $hooks{$subdir} || $subdir;

        if ($hook eq 'OutputFilter' and $module =~ /::i\w+$/) {
            #XXX: tmp hack
            $hook = 'InputFilter';
        }

        my $handler = join $hook, qw(Perl Handler);

        if ($self->server->{rev} < 2 and lc($hook) eq 'response') {
            $handler =~ s/response//i; #s/PerlResponseHandler/PerlHandler/
        }

        debug "configuring $module";

        if ($directives->{noautoconfig}) {
            $self->postamble(""); # which adds "\n"
        }
        else {
            if (my $cv = $add_hook_config{$hook}) {
                $self->$cv($module, \@args);
            }

            my $container = $container_config{$hook} || \&location_container;

            #unless the .pm test already configured the Perl*Handler
            unless ($directives->{$handler}) {
                my @handler_cfg = ($handler => $module);

                if ($outside_container{$handler}) {
                    $self->postamble(@handler_cfg);
                } else {
                    push @args, @handler_cfg;
                }
            }

            my $args_hash = list_to_hash_of_lists(\@args);
            $self->postamble($self->$container($module),
                $args_hash) if @args;
        }

        $self->write_pm_test($module, lc $base, lc $sub);
    }
}

# turn a balanced (key=>val) list with potentially multiple indentical
# keys into a hash of lists.
#############
sub list_to_hash_of_lists {
    my $arr = shift;
    my %hash = ();
    my $pairs = @$arr / 2;
    for my $i (0..($pairs-1)) {
        my ($key, $val) = ($arr->[$i*2], $arr->[$i*2+1]);
        push @{ $hash{$key} }, $val;
    }
    return \%hash;
}


# scan tests for interesting information
sub run_apache_test_config_scan {
    my ($self, $file) = @_;

    my @status = ();
    $status[APACHE_TEST_CONFIGURE]    = 0;
    $status[APACHE_TEST_CONFIG_ORDER] = 0;

    my $fh = Symbol::gensym();
    if (open $fh, $file) {
        local $/;
        my $content = <$fh>;
        close $fh;
        # XXX: optimize to match once?
        if ($content =~ /APACHE_TEST_CONFIGURE/m) {
            $status[APACHE_TEST_CONFIGURE] = 1;
        }
        if ($content =~ /APACHE_TEST_CONFIG_ORDER\s+([+-]?\d+)/m) {
            $status[APACHE_TEST_CONFIG_ORDER] = int $1;
        }
    }
    else {
        error "cannot open $file: $!";
    }

    return \@status;
}

# We have to test whether tests have APACHE_TEST_CONFIGURE() in them
# and run it if found at this stage, so when the server starts
# everything is ready.
# XXX: however we cannot use a simple require() because some tests
# won't require() outside of mod_perl environment. Therefore we scan
# the slurped file in.  and if APACHE_TEST_CONFIGURE has been found we
# require the file and run this function.
sub run_apache_test_configure {
    my ($self, $file, $module, $status) = @_;

    return unless $status->[APACHE_TEST_CONFIGURE];

    eval { require $file };
    warn $@ if $@;
    # double check that it's a real sub
    if ($module->can('APACHE_TEST_CONFIGURE')) {
        eval { $module->APACHE_TEST_CONFIGURE($self); };
        warn $@ if $@;
    }
}


1;
