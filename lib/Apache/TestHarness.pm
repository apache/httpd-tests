package Apache::TestHarness;

use strict;
use warnings FATAL => 'all';

use Test::Harness ();
use Apache::TestSort ();
use Apache::TestTrace;
use File::Spec::Functions qw(catfile);
use File::Find qw(finddepth);
use File::Basename qw(dirname);

sub chdir_t {
    chdir 't' if -d 't';
#Apache::TestConfig->new takes care of @INC
#    inc_fixup();
}

sub inc_fixup {
    # use blib
    unshift @INC, map "blib/$_", qw(lib arch);

    # fix all relative library locations
    for (@INC) {
        $_ = "../$_" unless m,^(/)|([a-f]:),i;
    }
}

#skip tests listed in t/SKIP
sub skip {
    my($self, $file) = @_;
    $file ||= 'SKIP';

    return unless -e $file;

    my $fh = Symbol::gensym();
    open $fh, $file or die "open $file: $!";
    my @skip;
    local $_;

    while (<$fh>) {
        chomp;
        s/^\s+//; s/\s+$//; s/^\#.*//;
        next unless $_;
        s/\*/.*/g;
        push @skip, $_;
    }

    close $fh;
    return join '|', @skip;
}

#test if all.t would skip tests or not
sub run_t {
    my($self, $file) = @_;
    my $ran = 0;
    my $cmd = "$^X -Mlib=../Apache-Test/lib $file";

    my $h = Symbol::gensym();
    open $h, "$cmd|" or die "open $cmd: $!";

    local $_;
    while (<$h>) {
        if (/^1\.\.(\d)/) {
            $ran = $1;
            last;
        }
    }

    close $h;

    $ran;
}

#if a directory has an all.t test
#skip all tests in that directory if all.t prints "1..0\n"
sub prune {
    my($self, @tests) = @_;
    my(@new_tests, %skip_dirs);
    local $_;

    for (@tests) {
        my $dir = dirname $_;
        if (m:\Wall\.t$:) {
            unless ($self->run_t($_)) {
                $skip_dirs{$dir} = 1;
                @new_tests = grep { not $skip_dirs{dirname $_} } @new_tests;
                push @new_tests, $_;
            }
        }
        elsif (!$skip_dirs{$dir}) {
            push @new_tests, $_;
        }
    }

    @new_tests;
}

sub get_tests {
    my $self = shift;
    my $args = shift;
    my @tests = ();

    chdir_t();

    my $ts = $args->{tests} || [];

    if (@$ts) {
	for (@$ts) {
	    if (-d $_) {
		push(@tests, sort <$_/*.t>);
	    }
	    else {
		$_ .= ".t" unless /\.t$/;
		push(@tests, $_);
	    }
	}
    }
    else {
        if ($args->{tdirs}) {
            push @tests, map { sort <$_/*.t> } @{ $args->{tdirs} };
        }
        else {
            finddepth(sub {
                          return unless /\.t$/;
                          my $t = catfile $File::Find::dir, $_;
                          my $dotslash = catfile '.', "";
                          $t =~ s:^\Q$dotslash::;
                          push @tests, $t
                      }, '.');
            @tests = sort @tests;
        }
    }

    @tests = $self->prune(@tests);

    if (my $skip = $self->skip) {
        @tests = grep { not /(?:$skip)/ } @tests;
    }

    Apache::TestSort->run(\@tests, $args);

    #when running 't/TEST t/dir' shell tab completion adds a /
    #dir//foo output is annoying, fix that.
    s:/+:/:g for @tests;

    return @tests;
}

sub run {
    my $self = shift;
    my $args = shift || {};

    $Test::Harness::verbose ||= $args->{verbose};

    if (my(@subtests) = @{ $args->{subtests} || [] }) {
        $ENV{HTTPD_TEST_SUBTESTS} = "@subtests";
    }

    Test::Harness::runtests($self->get_tests($args, @_));
}

1;
