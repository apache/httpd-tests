package Apache::TestConfig; #not TestConfigC on purpose

use strict;
use warnings FATAL => 'all';

use Config;
use Apache::TestConfig ();
use Apache::TestConfigPerl ();
use Apache::TestTrace;
use File::Find qw(finddepth);

sub cmodule_find {
    return unless /^mod_(\w+)\.c$/;
    my $sym = $1;

    my $dir = $File::Find::dir;
    my $file = catfile $dir, $_;

    open my $fh, $file or die "open $file: $!";
    my $v = <$fh>;
    if ($v =~ /^\#define\s+HTTPD_TEST_REQUIRE_APACHE\s+(\d+)/) {
        unless ($Apache::TestConfigC::apache_rev == $1) {
            notice "$_ requires Apache version $1, skipping.";
            return;
        }
    }
    close $fh;

    push @Apache::TestConfigC::modules, {
        name => "mod_$sym",
        sym => "${sym}_module",
        dir  => $dir,
        subdir => basename $dir,
    };
}

sub cmodules_configure {
    my($self, $dir) = @_;

    $dir ||= catfile $self->{vars}->{top_dir}, 'c-modules';

    unless (-d $dir) {
        return;
    }

    $self->{cmodules_dir} = $dir;

    local *Apache::TestConfigC::modules = $self->{cmodules} = [];
    local $Apache::TestConfigC::apache_rev = $self->{server}->{rev};

    finddepth(\&cmodule_find, $dir);

    $self->cmodules_write_makefiles;
    $self->cmodules_compile;
    $self->cmodules_httpd_conf;
}

sub cmodules_makefile_vars {
    return <<EOF;
MAKE = $Config{make}
EOF
}

sub cmodules_write_makefiles {
    my $self = shift;

    my $modules = $self->{cmodules};

    for (@$modules) {
        $self->cmodules_write_makefile($_);
    }

    my $file = catfile $self->{cmodules_dir}, 'Makefile';
    open my $fh, '>', $file or die "open $file: $!";

    print $fh $self->cmodules_makefile_vars;

    my @dirs = map { $_->{subdir} } @$modules;

    my @targets = qw(all clean);

    for my $dir (@dirs) {
        for my $targ (@targets) {
            print $fh "$dir-$targ:\n\t-cd $dir && \$(MAKE) $targ\n\n";
        }
    }

    for my $targ (@targets) {
        print $fh "$targ: ", (map { "$_-$targ " } @dirs), "\n\n";
    }

    close $fh or die "close $file: $!";
}

my %lib_dir = (1 => "", 2 => ".libs/");

sub cmodules_write_makefile {
    my($self, $mod) = @_;

    my $name = $mod->{name};
    my $makefile = "$mod->{dir}/Makefile";
    notice "writing $makefile";

    my $libdir = $self->server->version_of(\%lib_dir);
    my $lib = "$libdir$name.so";

    open my $fh, '>', $makefile or die "open $makefile: $!";

    print $fh <<EOF;
APXS=$self->{MP_APXS}
all: $lib

$lib: $name.c
	\$(APXS) -c $name.c

clean:
	-rm -rf $name.o $name.lo $name.slo $name.la .libs
EOF

    close $fh or die "close $makefile: $!";
}

sub cmodules_make {
    my $self = shift;
    my $targ = shift || 'all';

    my $cmd = "cd $self->{cmodules_dir} && $Config{make} $targ";
    notice $cmd;
    system $cmd;
}

sub cmodules_compile {
    shift->cmodules_make('all');
}

sub cmodules_httpd_conf {
    my $self = shift;

    my @args;

    for my $mod (@{ $self->{cmodules} }) {
        my $dir = $mod->{dir};
        my $so = "$dir/.libs/$mod->{name}.so";

        next unless -e $so;

        $self->preamble(LoadModule => "$mod->{sym} $so");

        my $cname = "$mod->{name}.c";
        my $cfile = "$dir/$cname";
        $self->{modules}->{$cname} = 1;

        $self->add_module_config($cfile, \@args);
    }

    $self->postamble(\@args) if @args;
}

sub cmodules_clean {
    my $self = shift;

    return unless $self->{cmodules_dir};

    $self->cmodules_make('clean');

    for my $mod (@{ $self->{cmodules} }) {
        my $makefile = "$mod->{dir}/Makefile";
        notice "unlink $makefile";
        unlink $makefile;
    }

    unlink "$self->{cmodules_dir}/Makefile";
}

1;
