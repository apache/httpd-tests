package Apache::TestConfig; #not TestConfigParse on purpose

#dont really want/need a full-blown parser
#but do want something somewhat generic

use strict;
use warnings FATAL => 'all';
use File::Spec::Functions qw(rel2abs splitdir);
use File::Basename qw(basename);

sub strip_quotes {
    local $_ = shift || $_;
    s/^\"//; s/\"$//; $_;
}

my %wanted_config = (
    TAKE1 => {map { $_, 1 } qw(ServerRoot ServerAdmin TypesConfig)},
    TAKE2 => {map { $_, 1 } qw(LoadModule)},
);

my %spec_init = (
    TAKE1 => sub { shift->{+shift} = "" },
    TAKE2 => sub { shift->{+shift} = [] },
);

my %spec_apply = (
    TypesConfig => \&inherit_server_file,
    ServerRoot  => sub {}, #dont override $self->{vars}->{serverroot}
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
sub server_file {
    my($self, $file, $base) = @_;

    $base ||= $self->{inherit_config}->{ServerRoot};
    my $f = rel2abs $file, $base;

    return qq("$f");
}

sub inherit_server_file {
    my($self, $c, $directive) = @_;

    $self->spec_add_config($directive,
                           $self->server_file($c->{$directive}));
}

#inherit LoadModule
sub inherit_load_module {
    my($self, $c, $directive) = @_;

    for my $args (@{ $c->{$directive} }) {
        my $modname = $args->[0];
        my $file = $self->server_file($args->[1]);

        my $name = basename $args->[1];
        $name =~ s/\.so$/.c/;  #mod_info.so => mod_info.c
        $name =~ s/^lib/mod_/; #libphp4.so => mod_php4.c
        $self->trace("LoadModule $modname $name");
        $self->{modules}->{$name} = 1;

        $self->preamble($directive => "$modname $file");
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

sub inherit_config {
    my $self = shift;

    $self->get_httpd_static_modules;
    $self->get_httpd_defines;

    my $file = $self->{vars}->{httpd_conf};

    unless ($file and -e $file) {
        if (my $base = $self->{httpd_basedir}) {
            my $default_conf = $self->{httpd_defines}->{SERVER_CONFIG_FILE};
            $default_conf ||= catfile qw(conf httpd.conf);
            $file = catfile $base, $default_conf;
        }
    }

    return unless $file;

    $self->trace("inheriting config file: $file");

    open(my $fh, $file) or return;

    my $c = $self->{inherit_config};

    #initialize array refs and such
    while (my($spec, $wanted) = each %wanted_config) {
        for my $directive (keys %$wanted) {
            $spec_init{$spec}->($c, $directive);
        }
    }

    while (<$fh>) {
        s/^\s*//; s/\s*$//; s/^\#.*//;
        next if /^$/;
        (my $directive, $_) = split /\s+/, $_, 2;

        #parse what we want
        while (my($spec, $wanted) = each %wanted_config) {
            next unless $wanted->{$directive};
            my $method = "parse_\L$spec";
            $self->$method($c, $directive);
        }
    }

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

    close $fh;
}

sub get_httpd_static_modules {
    my $self = shift;

    my $httpd = $self->{vars}->{httpd};
    return unless $httpd;

    my $cmd = "$httpd -l";
    open my $list, '-|', $cmd or die "$cmd failed: $!";

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
    open my $proc, '-|', $cmd or die "$cmd failed: $!";

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

    if (my $mpm_dir = $self->{httpd_defines}->{APACHE_MPM_DIR}) {
        $self->{mpm} = basename $mpm_dir;
    }
}

sub httpd_version {
    my $self = shift;

    my $httpd = $self->{vars}->{httpd};
    return unless $httpd;

    my $version;
    my $cmd = "$httpd -v";
    # untaint %ENV
    local %ENV;
    delete @ENV{ qw(PATH IFS CDPATH ENV BASH_ENV) };
    open my $v, '-|', $cmd or die "$cmd failed: $!";

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

1;
