package Apache::TestConfig;

use strict;
use warnings FATAL => 'all';

use constant WIN32 => $^O eq 'MSWin32';

use File::Spec::Functions qw(catfile abs2rel splitdir);
use Cwd qw(fastcwd);

use Apache::TestConfigPerl ();
use Apache::TestConfigParse ();

use Apache::TestServer ();

my %usage = (
   top_dir       => 'top-level directory (default is $PWD)',
   t_dir         => 'the t/ test directory (default is $top_dir/t)',
   t_conf        => 'the conf/ test directory (default is $t_dir/conf)',
   t_logs        => 'the logs/ test directory (default is $t_dir/logs)',
   t_conf_file   => 'test httpd.conf file (default is $t_conf/httpd.conf)',
   src_dir       => 'source directory to look for mod_foos.so',
   serverroot    => 'ServerRoot (default is $t_dir)',
   documentroot  => 'DocumentRoot (default is $ServerRoot/htdocs',
   port          => 'Port (default is 8529)',
   servername    => 'ServerName (default is localhost)',
   user          => 'User to run test server as (default is $USER)',
   group         => 'Group to run test server as (default is $GROUP)',
   bindir        => 'Apache bin/ dir (default is apxs -q SBINDIR)',
   httpd         => 'server to use for testing (default is $bindir/httpd)',
   target        => 'name of server binary (default is apxs -q TARGET)',
   apxs          => 'location of apxs (default is from Apache::BuildConfig)',
   httpd_conf    => 'inherit config from this file (default is apxs derived)',
);

sub usage {
    for my $hash (\%usage) {
        while (my($key, $val) = each %$hash) {
            printf "   %-16s %s\n", $key, $val;
        }
    }
}

my %passenv = map { $_,1 } qw{
APXS APACHE APACHE_GROUP APACHE_USER APACHE_PORT
};

sub passenv {
    \%passenv;
}

sub server { shift->{server} }

sub build_config {
    eval {
        require Apache::BuildConfig;
    } or return undef;
    return Apache::Build->build_config;
}

sub new_test_server {
    my($self, $args) = @_;
    Apache::TestServer->new($args || $self)
}

sub new {
    my($class, $args) = @_;

    $args = ($args and ref($args)) ? {%$args} : {@_}; #copy

    my $thaw = {};

    #thaw current config
    for (qw(conf t/conf)) {
        last if eval {
            require "$_/apache_test_config.pm";
            $thaw = 'apache_test_config'->new;
            delete $thaw->{save};
        };
    };

    if ($args->{thaw}) {
        #dont generate any new config
        $thaw->{$_} = $args->{$_} for keys %$args;
        $thaw->{server} = $thaw->new_test_server;
        return $thaw;
    }

    #regenerating config, so forget old
    if ($args->{save}) {
        for (qw(vhosts inherit_config modules inc)) {
            delete $thaw->{$_} if exists $thaw->{$_};
        }
    }

    my $self = bless {
        clean => {},
        vhosts => {},
        inherit_config => {},
        modules => {},
        inc => [],
        %$thaw,
        vars => $args,
        postamble => [],
        preamble => [],
        postamble_hooks => [],
        preamble_hooks => [],
    }, $class;

    my $vars = $self->{vars}; #things that can be overridden

    for (qw(save verbose)) {
        next unless exists $args->{$_};
        $self->{$_} = delete $args->{$_};
    }

    $vars->{top_dir} ||= fastcwd;
    $vars->{top_dir} = pop_dir($vars->{top_dir}, 't');

    $self->add_inc;

    #help to find libmodperl.so
    my $src_dir = catfile $vars->{top_dir}, qw(src modules perl);
    $vars->{src_dir}      ||= $src_dir if -d $src_dir;

    $vars->{t_dir}        ||= catfile $vars->{top_dir}, 't';
    $vars->{serverroot}   ||= $vars->{t_dir};
    $vars->{documentroot} ||= catfile $vars->{serverroot}, 'htdocs';
    $vars->{t_conf}       ||= catfile $vars->{serverroot}, 'conf';
    $vars->{t_logs}       ||= catfile $vars->{serverroot}, 'logs';
    $vars->{t_conf_file}  ||= catfile $vars->{t_conf},   'httpd.conf';

    $vars->{port}         ||= $self->default_port;
    $vars->{servername}   ||= $self->default_servername;
    $vars->{user}         ||= $self->default_user;
    $vars->{group}        ||= $self->default_group;
    $vars->{serveradmin}  ||= join '@', $vars->{user}, $vars->{servername};

    $self->configure_apxs;
    $self->configure_httpd;
    $self->inherit_config; #see TestConfigParse.pm

    $self->{hostport} = $self->hostport;

    $self->{server} = $self->new_test_server;

    $self;
}

sub configure_apxs {
    my $self = shift;

    return unless $self->{MP_APXS} = $self->default_apxs;
    my $vars = $self->{vars};

    $vars->{bindir}   ||= $self->apxs('SBINDIR');
    $vars->{target}   ||= $self->apxs('TARGET');
    $vars->{conf_dir} ||= $self->apxs('SYSCONFDIR');

    if ($vars->{conf_dir}) {
        $vars->{httpd_conf} ||= catfile $vars->{conf_dir}, 'httpd.conf';
    }
}

sub configure_httpd {
    my $self = shift;
    my $vars = $self->{vars};

    $vars->{target} ||= 'httpd';

    if ($vars->{bindir}) {
        $vars->{httpd} ||= catfile $vars->{bindir}, $vars->{target};
    }
    else {
        $vars->{httpd} ||= $self->default_httpd;
    }

    if ($vars->{httpd}) {
        my @chunks = splitdir $vars->{httpd};
        pop @chunks for 1..2; #bin/httpd
        $self->{httpd_basedir} = catfile @chunks;
    }

    #cleanup httpd droppings
    my $sem = catfile $vars->{t_logs}, 'apache_runtime_status.sem';
    unless (-e $sem) {
        $self->{clean}->{files}->{$sem} = 1;
    }
}

sub add_config {
    my $self = shift;
    my $where = shift;
    my($directive, $arg, $hash) = @_;
    my $args = "";

    if ($hash) {
        $args = "<$directive $arg>\n";
        if (ref($hash)) {
            while (my($k,$v) = each %$hash) {
                $args .= "   $k $v\n";
            }
        }
        else {
            $args .= "   $hash";
        }
        $args .= "</$directive>";
    }
    elsif (ref($directive) eq 'ARRAY') {
        $args = join "\n", @$directive;
    }
    else {
        $args = "$directive " .
          (ref($arg) && (ref($arg) eq 'ARRAY') ? "@$arg" : $arg);
    }

    push @{ $self->{$where} }, $args;
}

sub postamble {
    shift->add_config(postamble => @_);
}

sub preamble {
    shift->add_config(preamble => @_);
}

sub postamble_register {
    push @{ shift->{postamble_hooks} }, @_;
}

sub preamble_register {
    push @{ shift->{preamble_hooks} }, @_;
}

sub add_config_hooks_run {
    my($self, $where, $out) = @_;

    for (@{ $self->{"${where}_hooks"} }) {
        $self->$_();
    }

    for (@{ $self->{$where} }) {
        $self->replace;
        print $out "$_\n";
    }
}

sub postamble_run {
    shift->add_config_hooks_run(postamble => @_);
}

sub preamble_run {
    shift->add_config_hooks_run(preamble => @_);
}

sub default_group {
    my $gid = $);

    #use only first value if $) contains more than one
    $gid =~ s/^(\d+).*$/$1/;

    WIN32 ? 'nogroup' :
        $ENV{APACHE_GROUP} || (getgrgid($gid) || "#$gid");
}

sub default_user {
    my $uid = $>;

    my $user = WIN32 ? 'nobody' :
      $ENV{APACHE_USER} || (getpwuid($uid) || "#$uid");

    if ($user eq 'root') {
	my $other = (getpwnam('nobody'))[0];
        if ($other) {
            $user = $other;
        }
        else {
            die "cannot run tests as User root";
            #XXX: prompt for another username
        }
    }

    $user;
}

sub default_apxs {
    my $self = shift;

    return $self->{vars}->{apxs} if $self->{vars}->{apxs};

    if (my $build_config = build_config()) {
        return $build_config->{MP_APXS};
    }

    $ENV{APXS} || which('apxs');
}

sub default_httpd {
    my $vars = shift->{vars};

    $ENV{APACHE} || which($vars->{target});
}

sub default_servername {
    'localhost';
}

#XXX: could check if the port is in use and select another if so
sub default_port {
    $ENV{APACHE_PORT} || 8529;
}

sub default_loopback {
    '127.0.0.1';
}

sub port {
    my($self, $module) = @_;
    return $self->{vars}->{port} unless $module;
    return $self->{vhosts}->{$module}->{port};
}

sub hostport {
    my $self = shift;
    my $vars = shift || $self->{vars};

    my $name = $vars->{servername};
    my $resolve = \$self->{resolved}->{$name};

    unless ($$resolve) {
        if (gethostbyname $name) {
            $$resolve = $name;
        }
        else {
            $$resolve = $self->default_loopback;
            warn "lookup $name failed, using $$resolve for client tests\n";
        }
    }

    join ':', $$resolve, $vars->{port};
}

#look for mod_foo.so
sub find_apache_module {
    my($self, $module) = @_;

    my $vars = $self->{vars};
    my $sroot = $vars->{serverroot};

    my @trys = grep { $_ }
      ($vars->{src_dir},
       $self->apxs('LIBEXECDIR'),
       catfile($sroot, 'modules'),
       catfile($sroot, 'libexec'));

    for (@trys) {
        my $file = catfile $_, $module;
        if (-e $file) {
            $self->trace("found $module => $file");
            return $file;
        }
    }
}

#generate files and directories

sub genwarning {
    my($self, $type) = @_;
    return unless $type;
    return "#WARNING: this file is generated, do not edit\n";
}

sub genfile {
    my($self, $file, $warn) = @_;

    my $name = abs2rel $file, $self->{vars}->{t_dir};
    $self->trace("generating $name");

    open my $fh, '>', $file or die "open $file: $!";

    if (my $msg = $self->genwarning($warn)) {
        print $fh $msg, "\n";
    }

    $self->{clean}->{files}->{$file} = 1;

    return $fh;
}

sub gendir {
    my($self, $dir) = @_;

    mkdir $dir, 0755 unless -d $dir;
    $self->{clean}->{dirs}->{$dir} = 1;
}

sub clean {
    my $self = shift;

    for (keys %{ $self->{clean}->{files} }) {
        if (-e $_) {
            $self->trace("unlink $_");
            unlink $_;
        }
        else {
            #print "unlink $_: $!\n";
        }
    }

    for (keys %{ $self->{clean}->{dirs} }) {
        if (-d $_) {
            opendir(my $dh, $_);
            my $notempty = grep { ! /^\.{1,2}$/ } readdir $dh;
            closedir $dh;
            next if $notempty;
            $self->trace("rmdir $_");
            rmdir $_;
        }
    }

    $self->new_test_server->clean;
}

sub replace {
    my $self = shift;
    s/@(\w+)@/$self->{vars}->{lc $1}/g;
}

sub replace_vars {
    my($self, $in, $out) = @_;

    local $_;
    while (<$in>) {
        $self->replace;
        print $out $_;
    }
}

sub index_html_template {
    my $self = shift;
    return "welcome to $self->{server}->{name}\n";
}

sub generate_index_html {
    my $self = shift;
    my $dir = $self->{vars}->{documentroot};
    $self->gendir($dir);
    my $file = catfile $dir, 'index.html';
    return if -e $file;
    my $fh = $self->genfile($file);
    print $fh $self->index_html_template;
}

sub types_config_template {
    "text/html html htm\n";
}

sub generate_types_config {
    my $self = shift;

    unless ($self->{inherit_config}->{TypesConfig}) {
        my $types = catfile $self->{vars}->{t_conf}, 'mime.types';
        unless (-e $types) {
            my $fh = $self->genfile($types, 1);
            print $fh $self->types_config_template;
            close $fh;
        }
        $self->postamble(TypesConfig => qq("$types"));
    }
}

sub httpd_conf_template {
    my($self, $try) = @_;

    if (open my $in, $try) {
        return $in;
    }
    else {
        return \*DATA;
    }
}

sub generate_extra_conf {
    my $self = shift;

    my $extra_conf = catfile $self->{vars}->{t_conf}, 'extra.conf';
    return $extra_conf if -e $extra_conf;

    my $extra_conf_in = join '.', $extra_conf, 'in';
    open(my $in, $extra_conf_in) or return;

    my $out = $self->genfile($extra_conf, 1);
    $self->replace_vars($in, $out);

    close $in;
    close $out;

    return $extra_conf;
}

sub generate_httpd_conf {
    my $self = shift;

    #generated httpd.conf depends on these things to exist
    $self->generate_types_config;
    $self->generate_index_html;

    for (qw(t_logs t_conf)) {
        $self->gendir($self->{vars}->{$_});
    }

    if (my $extra_conf = $self->generate_extra_conf) {
        $self->postamble(Include => qq("$extra_conf"));
    }

    my $conf_file = $self->{vars}->{t_conf_file};
    my $conf_file_in = join '.', $conf_file, 'in';

    my $in = $self->httpd_conf_template($conf_file_in);

    my $out = $self->genfile($conf_file, 1);

    $self->preamble_run($out);

    $self->replace_vars($in, $out);

    print $out "\n";

    $self->postamble_run($out);

    close $in;
    close $out or die "close $conf_file: $!";
}

#shortcuts

my %include_headers = (GET => 1, HEAD => 2);

sub http_raw_get {
    my($self, $url, $h) = @_;

    $url = "/$url" unless $url =~ m:^/:;

    my $ih = exists $include_headers{$h ||= 0} ?
      $include_headers{$h} : $h;

    require Apache::TestRequest;
    Apache::TestRequest::http_raw_get($self->{hostport},
                                      $url, $ih);
}

sub error_log {
    my($self, $rel) = @_;
    my $file = catfile $self->{vars}->{t_logs}, 'error_log';
    return $file unless $rel;
    return abs2rel $file, $self->{vars}->{top_dir};
}


#utils

sub trace {
    my $self = shift;
    return unless $self->{verbose};
    print "@_\n";
}

#duplicating small bits of Apache::Build so we dont require it
sub which {
    foreach (map { catfile $_, $_[0] } File::Spec->path) {
	return $_ if -x;
    }
}

sub apxs {
    my($self, $q) = @_;
    return unless $self->{MP_APXS};
    my $val = qx($self->{MP_APXS} -q $q 2>/dev/null);
    warn "APXS ($self->{MP_APXS}) query for $q failed\n" unless $val;
    $val;
}

sub pop_dir {
    my $dir = shift;

    my @chunks = splitdir $dir;
    while (my $remove = shift) {
        pop @chunks if $chunks[-1] eq $remove;
    }

    catfile @chunks;
}

sub add_inc {
    my $self = shift;
    require lib;
    lib::->import(map "$self->{vars}->{top_dir}/$_",
                  qw(lib blib/lib blib/arch));
    #print join "\n", @INC, "";
}

#freeze/thaw so other processes can access config

sub thaw {
    my $class = shift;
    $class->new({thaw => 1, @_});
}

sub freeze {
    require Data::Dumper;
    local $Data::Dumper::Terse = 1;
    my $data = Data::Dumper::Dumper(shift);
    chomp $data;
    $data;
}

sub save {
    my($self) = @_;

    return unless $self->{save};

    my $name = 'apache_test_config';
    my $file = catfile $self->{vars}->{t_conf}, "$name.pm";
    my $fh = $self->genfile($file, 1);

    $self->trace("saving config data to $name.pm");

    (my $obj = $self->freeze) =~ s/^/    /;

    print $fh <<EOF;
package $name;

sub new {
$obj;
}

1;
EOF

    close $fh or die "failed to write $file: $!";
}

1;
__DATA__
ServerRoot   "@ServerRoot@"
DocumentRoot "@DocumentRoot@"

Listen     @Port@
Group      @Group@
User       @User@
ServerName @ServerName@

PidFile     @t_logs@/httpd.pid
ErrorLog    @t_logs@/error_log
LogLevel    debug
TransferLog @t_logs@/access_log

ServerAdmin @ServerAdmin@

KeepAlive       Off
HostnameLookups Off

<Directory />
    Options FollowSymLinks
    AllowOverride None
</Directory>

<IfModule threaded.c>
    StartServers         1
    MaxClients           1
    MinSpareThreads      1
    MaxSpareThreads      1
    ThreadsPerChild      1
    MaxRequestsPerChild  0
</IfModule>

<IfModule prefork.c>
    StartServers         1
    MaxClients           1
    MaxRequestsPerChild  0
</IfModule>

<Location /server-info>
    SetHandler server-info
</Location>

<Location /server-status>
    SetHandler server-status
</Location>
