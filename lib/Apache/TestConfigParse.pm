package Apache::TestConfig; #not TestConfigParse on purpose

#dont really want/need a full-blown parser
#but do want something somewhat generic

use strict;
use warnings FATAL => 'all';

use Apache::TestTrace;

use File::Spec::Functions qw(rel2abs splitdir);
use File::Basename qw(basename);

sub strip_quotes {
    local $_ = shift || $_;
    s/^\"//; s/\"$//; $_;
}

my %wanted_config = (
    TAKE1 => {map { $_, 1 } qw(ServerRoot ServerAdmin TypesConfig DocumentRoot)},
    TAKE2 => {map { $_, 1 } qw(LoadModule)},
);

my %spec_init = (
    TAKE1 => sub { shift->{+shift} = "" },
    TAKE2 => sub { shift->{+shift} = [] },
);

my %spec_apply = (
    TypesConfig => \&inherit_server_file,
    ServerRoot  => sub {}, #dont override $self->{vars}->{serverroot}
    DocumentRoot => \&inherit_directive_var,
    LoadModule  => \&inherit_load_module,
);

#where to add config, default is preamble
my %spec_postamble = map { $_, 'postamble' } qw(TypesConfig);

sub spec_add_config {
    my($self, $directive, $val) = @_;

    my $where = $spec_postamble{$directive} || 'preamble';
    $self->$where($directive => $val);
}

#resolve relative files like Apache->server_root_relative
sub server_file_rel2abs {
    my($self, $file, $base) = @_;

    $base ||= $self->{inherit_config}->{ServerRoot};

    unless ($base) {
        warning "unable to resolve $file (ServerRoot not defined yet?)";
        return $file;
    }

    rel2abs $file, $base;
}

sub server_file {
    my $f = shift->server_file_rel2abs(@_);
    return qq("$f");
}

sub inherit_directive_var {
    my($self, $c, $directive) = @_;

    $self->{vars}->{"inherit_\L$directive"} = $c->{$directive};
}

sub inherit_server_file {
    my($self, $c, $directive) = @_;

    $self->spec_add_config($directive,
                           $self->server_file($c->{$directive}));
}

#so we have the same names if these modules are linked static or shared
my %modname_alias = (
    'mod_pop.c'           => 'pop_core.c',
    'mod_proxy_http.c'    => 'proxy_http.c',
    'mod_proxy_ftp.c'     => 'proxy_ftp.c',
    'mod_proxy_connect.c' => 'proxy_connect.c',
    'mod_modperl.c'       => 'mod_perl.c',
);

#XXX mod_jk requires JkWorkerFile or JkWorker to be configured
#skip it for now, tomcat has its own test suite anyhow.
#XXX: mod_casp2.so requires other settings in addition to LoadModule
my %autoconfig_skip_module = map { $_, 1 } qw(mod_jk.c mod_casp2.c);

# add modules to be not inherited from the existing config.
# e.g. prevent from LoadModule perl_module to be included twice, when
# mod_perl already configures LoadModule and it's certainly found in
# the existing httpd.conf installed system-wide.
sub autoconfig_skip_module_add {
    my($name) = @_;
    $autoconfig_skip_module{$name} = 1;
}

sub should_skip_module {
    my($self, $name) = @_;
    return $autoconfig_skip_module{$name} ? 1 : 0;
}

#inherit LoadModule
sub inherit_load_module {
    my($self, $c, $directive) = @_;

    for my $args (@{ $c->{$directive} }) {
        my $modname = $args->[0];
        my $file = $self->server_file_rel2abs($args->[1]);

        unless (-e $file) {
            debug "$file does not exist, skipping LoadModule";
            next;
        }

        my $name = basename $args->[1];
        $name =~ s/\.s[ol]$/.c/;  #mod_info.so => mod_info.c
        $name =~ s/^lib/mod_/; #libphp4.so => mod_php4.c

        $name = $modname_alias{$name} if $modname_alias{$name};

        # remember all found modules
        $self->{modules}->{$name} = $file;
        debug "Found: $modname => $name";

        if ($self->should_skip_module($name)) {
            debug "Skipping LoadModule of $name";
            next;
        }

        debug "LoadModule $modname $name";

        # sometimes people have broken system-wide httpd.conf files,
        # which include LoadModule of modules, which are built-in, but
        # won't be skipped above if they are found in the modules/
        # directory. this usually happens when httpd is built once
        # with its modules built as shared objects and then again with
        # static ones: the old httpd.conf still has the LoadModule
        # directives, even though the modules are now built-in
        # so we try to workaround this problem using <IfModule>
        $self->preamble(IfModule => "!$name",
                        qq{LoadModule $modname "$file"\n});
    }
}

sub parse_take1 {
    my($self, $c, $directive) = @_;
    $c->{$directive} = strip_quotes;
}

sub parse_take2 {
    my($self, $c, $directive) = @_;
    push @{ $c->{$directive} }, [map { strip_quotes } split];
}

sub apply_take1 {
    my($self, $c, $directive) = @_;

    if (exists $self->{vars}->{lc $directive}) {
        #override replacement @Variables@
        $self->{vars}->{lc $directive} = $c->{$directive};
    }
    else {
        $self->spec_add_config($directive, qq("$c->{$directive}"));
    }
}

sub apply_take2 {
    my($self, $c, $directive) = @_;

    for my $args (@{ $c->{$directive} }) {
        $self->spec_add_config($directive => [map { qq("$_") } @$args]);
    }
}

sub inherit_config_file_or_directory {
    my ($self, $item) = @_;

    if (-d $item) {
        my $dir = $item;
        debug "descending config directory: $dir";

        for my $entry (glob "$dir/*") {
            $self->inherit_config_file_or_directory($entry);
        }
        return;
    }

    my $file = $item;
    debug "inheriting config file: $file";

    my $fh = Symbol::gensym();
    open($fh, $file) or return;

    my $c = $self->{inherit_config};
    while (<$fh>) {
        s/^\s*//; s/\s*$//; s/^\#.*//;
        next if /^$/;
        (my $directive, $_) = split /\s+/, $_, 2;

        if ($directive eq "Include") {
            my $include = $self->server_file_rel2abs($_);
            $self->inherit_config_file_or_directory($include);
        }

        #parse what we want
        while (my($spec, $wanted) = each %wanted_config) {
            next unless $wanted->{$directive};
            my $method = "parse_\L$spec";
            $self->$method($c, $directive);
        }
    }

    close $fh;
}

sub inherit_config {
    my $self = shift;

    $self->get_httpd_static_modules;
    $self->get_httpd_defines;

    #may change after parsing httpd.conf
    $self->{vars}->{inherit_documentroot} =
      catfile $self->{httpd_basedir}, 'htdocs';

    my $file = $self->{vars}->{httpd_conf};

    unless ($file and -e $file) {
        if (my $base = $self->{httpd_basedir}) {
            my $default_conf = $self->{httpd_defines}->{SERVER_CONFIG_FILE};
            $default_conf ||= catfile qw(conf httpd.conf);
            $file = catfile $base, $default_conf;
            # SERVER_CONFIG_FILE might be an absolute path
            $file = $default_conf if !-e $file and -e $default_conf;
        }
    }

    return unless $file;

    my $c = $self->{inherit_config};

    #initialize array refs and such
    while (my($spec, $wanted) = each %wanted_config) {
        for my $directive (keys %$wanted) {
            $spec_init{$spec}->($c, $directive);
        }
    }

    $self->inherit_config_file_or_directory($file);

    #apply what we parsed
    while (my($spec, $wanted) = each %wanted_config) {
        for my $directive (keys %$wanted) {
            next unless $c->{$directive};
            my $cv = $spec_apply{$directive} ||
                     $self->can("apply_\L$directive") ||
                     $self->can("apply_\L$spec");
            $cv->($self, $c, $directive);
        }
    }
}

sub get_httpd_static_modules {
    my $self = shift;

    my $httpd = $self->{vars}->{httpd};
    return unless $httpd;

    my $cmd = "$httpd -l";
    my $list = $self->open_cmd($cmd);

    while (<$list>) {
        s/\s+$//;
        next unless /\.c$/;
        chomp;
        s/^\s+//;
        $self->{modules}->{$_} = 1;
    }

    close $list;
}

sub get_httpd_defines {
    my $self = shift;

    my $httpd = $self->{vars}->{httpd};
    return unless $httpd;

    my $cmd = "$httpd -V";
    my $proc = $self->open_cmd($cmd);

    while (<$proc>) {
        chomp;
        if( s/^\s*-D\s*//) {
            s/\s+$//;
            my($key, $val) = split '=', $_, 2;
            $self->{httpd_defines}->{$key} = $val ? strip_quotes($val) : 1;
        }
        elsif (/(version|built|module magic number):\s+(.*)/i) {
            my $val = $2;
            (my $key = uc $1) =~ s/\s/_/g;
            $self->{httpd_info}->{$key} = $val;
        }
    }

    close $proc;

    if (my $mmn = $self->{httpd_info}->{MODULE_MAGIC_NUMBER}) {
        @{ $self->{httpd_info} }
          {qw(MODULE_MAGIC_NUMBER_MAJOR
              MODULE_MAGIC_NUMBER_MINOR)} = split ':', $mmn;
    }

    if (my $mpm_dir = $self->{httpd_defines}->{APACHE_MPM_DIR}) {
        $self->{mpm} = basename $mpm_dir;
    }
    else {
        # Apache 1.3 - no mpm to speak of
        $self->{mpm} = '';
    }
}

sub httpd_version {
    my $self = shift;

    my $httpd = $self->{vars}->{httpd};
    return unless $httpd;

    my $version;
    my $cmd = "$httpd -v";

    my $v = $self->open_cmd($cmd);

    local $_;
    while (<$v>) {
        next unless s/^Server\s+version:\s*//i;
        chomp;
        my @parts = split;
        foreach (@parts) {
            next unless /^Apache\//;
            $version = $_;
            last;
        }
        $version ||= $parts[0];
        last;
    }

    close $v;

    return $version;
}

sub httpd_mpm {
    return shift->{mpm};
}

1;
