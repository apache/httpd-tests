package Apache::TestUtil;

use strict;
use warnings FATAL => 'all';

use File::Find ();
use File::Path ();
use Exporter ();
use Carp ();
use Config;
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use Symbol ();

use Apache::Test ();
use Apache::TestConfig ();

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %CLEAN);

$VERSION = '0.01';
@ISA     = qw(Exporter);

@EXPORT = qw(t_cmp t_debug t_append_file t_write_file t_open_file
    t_mkdir t_rmtree t_is_equal
    t_server_log_error_is_expected t_server_log_warn_is_expected
    t_client_log_error_is_expected t_client_log_warn_is_expected
);

@EXPORT_OK = qw(t_write_perl_script t_write_shell_script t_chown);

%CLEAN = ();

# 5.005's Data::Dumper has problems to dump certain datastructures
use constant HAS_DUMPER => eval { $] >= 5.6 && require Data::Dumper; };
use constant INDENT     => 4;

sub t_cmp {
    Carp::carp(join(":", (caller)[1..2]) . 
        ' usage: $res = t_cmp($expected, $received, [$comment])')
            if @_ < 2 || @_ > 3;

    t_debug("testing : " . pop) if @_ == 3;
    t_debug("expected: " . struct_as_string(0, $_[0]));
    t_debug("received: " . struct_as_string(0, $_[1]));
    return t_is_equal(@_);
}

*expand = HAS_DUMPER ?
    sub { map { ref $_ ? Data::Dumper::Dumper($_) : $_ } @_ } :
    sub { @_ };

sub t_debug {
    print map {"# $_\n"} map {split /\n/} grep {defined} expand(@_);
}

sub t_open_file {
    my $file = shift;

    die "must pass a filename" unless defined $file;

    # create the parent dir if it doesn't exist yet
    makepath(dirname $file);

    my $fh = Symbol::gensym();
    open $fh, ">$file" or die "can't open $file: $!";
    t_debug("writing file: $file");
    $CLEAN{files}{$file}++;

    return $fh;
}

sub t_write_file {
    my $file = shift;

    die "must pass a filename" unless defined $file;

    # create the parent dir if it doesn't exist yet
    makepath(dirname $file);

    my $fh = Symbol::gensym();
    open $fh, ">$file" or die "can't open $file: $!";
    t_debug("writing file: $file");
    print $fh join '', @_ if @_;
    close $fh;
    $CLEAN{files}{$file}++;
}

sub t_append_file {
    my $file = shift;

    die "must pass a filename" unless defined $file;

    # create the parent dir if it doesn't exist yet
    makepath(dirname $file);

    # add to the cleanup list only if we created it now
    $CLEAN{files}{$file}++ unless -e $file;

    my $fh = Symbol::gensym();
    open $fh, ">>$file" or die "can't open $file: $!";
    print $fh join '', @_ if @_;
    close $fh;
}

sub t_write_shell_script {
    my $file = shift;

    my $code = join '', @_;
    my($ext, $shebang);

    if (Apache::TestConfig::WIN32()) {
        $code =~ s/echo$/echo./mg; #required to echo newline
        $ext = 'bat';
        $shebang = "\@echo off\nREM this is a bat";
    }
    else {
        $ext = 'sh';
        $shebang = '#!/bin/sh';
    }

    $file .= ".$ext";
    t_write_file($file, "$shebang\n", $code);
    $ext;
}

sub t_write_perl_script {
    my $file = shift;

    my $shebang = "#!$Config{perlpath}\n";
    my $warning = Apache::TestConfig->thaw->genwarning($file);
    t_write_file($file, $shebang, $warning, @_);
    chmod 0755, $file;
}


sub t_mkdir {
    my $dir = shift;
    makepath($dir);
}

# returns a list of dirs successfully created
sub makepath {
    my($path) = @_;

    return if !defined($path) || -e $path;
    my $full_path = $path;

    # remember which dirs were created and should be cleaned up
    while (1) {
        $CLEAN{dirs}{$path} = 1;
        $path = dirname $path;
        last if -e $path;
    }

    return File::Path::mkpath($full_path, 0, 0755);
}

sub t_rmtree {
    die "must pass a dirname" unless defined $_[0];
    File::Path::rmtree((@_ > 1 ? \@_ : $_[0]), 0, 1);
}

#chown a file or directory to the test User/Group
#noop if chown is unsupported

sub t_chown {
    my $file = shift;
    my $config = Apache::Test::config();
    my($uid, $gid);

    eval {
        #XXX cache this lookup
        ($uid, $gid) = (getpwnam($config->{vars}->{user}))[2,3];
    };

    if ($@) {
        if ($@ =~ /^The getpwnam function is unimplemented/) {
            #ok if unsupported, e.g. win32
            return 1;
        }
        else {
            die $@;
        }
    }

    CORE::chown($uid, $gid, $file) || die "chown $file: $!";
}

# $string = struct_as_string($indent_level, $var);
#
# return any nested datastructure via Data::Dumper or ala Data::Dumper
# as a string. undef() is a valid arg.
#
# $indent_level should be 0 (used for nice indentation during
# recursive datastructure traversal)
sub struct_as_string{
    return "???"   unless @_ == 2;
    my $level = shift;

    return "undef" unless defined $_[0];
    my $pad  = ' ' x (($level + 1) * INDENT);
    my $spad = ' ' x ($level       * INDENT);

    if (HAS_DUMPER) {
        local $Data::Dumper::Terse = 1;
        $Data::Dumper::Terse = $Data::Dumper::Terse; # warn
        my $data = Data::Dumper::Dumper(@_);
        $data =~ s/\n$//; # \n is handled by the caller
        return $data;
    }
    else {
        if (ref($_[0]) eq 'ARRAY') {
            my @data = ();
            for my $i (0..$#{ $_[0] }) {
                push @data,
                    struct_as_string($level+1, $_[0]->[$i]);
            }
            return join "\n", "[", map({"$pad$_,"} @data), "$spad\]";
        } elsif ( ref($_[0])eq 'HASH') {
            my @data = ();
            for my $key (keys %{ $_[0] }) {
                push @data,
                    "$key => " .
                    struct_as_string($level+1, $_[0]->{$key});
            }
            return join "\n", "{", map({"$pad$_,"} @data), "$spad\}";
        } else {
            return $_[0];
        }
    }
}

# compare any two datastructures (must pass references for non-scalars)
# undef()'s are valid args
sub t_is_equal {
    my ($a, $b) = @_;
    return 0 unless @_ == 2;

    if (defined $a && defined $b) {
        my $ref_a = ref $a;
        my $ref_b = ref $b;
        if (!$ref_a && !$ref_b) {
            return $a eq $b;
        }
        elsif ($ref_a eq 'ARRAY' && $ref_b eq 'ARRAY') {
            return 0 unless @$a == @$b;
            for my $i (0..$#$a) {
                t_is_equal($a->[$i], $b->[$i]) || return 0;
            }
        }
        elsif ($ref_a eq 'HASH' && $ref_b eq 'HASH') {
            return 0 unless (keys %$a) == (keys %$b);
            for my $key (sort keys %$a) {
                return 0 unless exists $b->{$key};
                t_is_equal($a->{$key}, $b->{$key}) || return 0;
            }
        }
        elsif ($ref_a eq 'Regexp') {
            return $b =~ $a;
        }
        else {
            # try to compare the references
            return $a eq $b;
        }
    }
    else {
        # undef == undef! a valid test
        return (defined $a || defined $b) ? 0 : 1;
    }
    return 1;
}

my $banner_format = 
    "\n*** The following %s entry is expected and it is harmless ***\n";
sub t_server_log_is_expected { printf STDERR $banner_format, $_[0]; }

sub t_client_log_is_expected {
    my $vars = Apache::Test::config()->{vars};
    my $log_file = catfile $vars->{serverroot}, "logs", "error_log";

    my $fh = Symbol::gensym();
    open $fh, ">>$log_file" or die "Can't open $log_file: $!";
    my $oldfh = select($fh); $| = 1; select($oldfh);
    printf $fh $banner_format, $_[0];
    close $fh;
}

sub t_server_log_error_is_expected { t_server_log_is_expected("error");}
sub t_server_log_warn_is_expected  { t_server_log_is_expected("warn"); }
sub t_client_log_error_is_expected { t_client_log_is_expected("error");}
sub t_client_log_warn_is_expected  { t_client_log_is_expected("warn"); }

END {
    # remove files that were created via this package
    for (grep {-e $_ && -f _ } keys %{ $CLEAN{files} } ) {
        t_debug("removing file: $_");
        unlink $_;
    }

    # remove dirs that were created via this package
    for (grep {-e $_ && -d _ } keys %{ $CLEAN{dirs} } ) {
        t_debug("removing dir tree: $_");
        t_rmtree($_);
    }
}

1;
__END__


=head1 NAME

Apache::TestUtil - Utility functions for writing tests

=head1 SYNOPSIS

  use Apache::Test;
  use Apache::TestUtil;

  ok t_cmp("foo", "foo", "sanity check");
  t_write_file("filename", @content);
  my $fh = t_open_file($filename);
  t_mkdir("/foo/bar");
  t_rmtree("/foo/bar");
  t_is_equal($a, $b);

=head1 DESCRIPTION

C<Apache::TestUtil> automatically exports a number of functions useful
in writing tests.

All the files and directories created using the functions from this
package will be automatically destroyed at the end of the program
execution (via END block). You should not use these functions other
than from within tests which should cleanup all the created
directories and files at the end of the test.

=head1 FUNCTIONS

=over

=item t_cmp()

  t_cmp($expected, $received, $comment);

t_cmp() prints the values of I<$comment>, I<$expected> and
I<$received>. e.g.:

  t_cmp(1, 1, "1 == 1?");

prints:

  # testing : 1 == 1?
  # expected: 1
  # received: 1

then it returns the result of comparison of the I<$expected> and the
I<$received> variables. Usually, the return value of this function is
fed directly to the ok() function, like this:

  ok t_cmp(1, 1, "1 == 1?");

the third argument (I<$comment>) is optional, mostly useful for
telling what the comparison is trying to do.

It is valid to use C<undef> as an expected value. Therefore:

  my $foo;
  t_cmp(undef, $foo, "undef == undef?");

will return a I<true> value.

You can compare any two data-structures with t_cmp(). Just make sure
that if you pass non-scalars, you have to pass their references. The
datastructures can be deeply nested. For example you can compare:

  t_cmp({1 => [2..3,{5..8}], 4 => [5..6]},
        {1 => [2..3,{5..8}], 4 => [5..6]},
        "hash of array of hashes");

You can also compare the second argument against the first as a
regex. Use the C<qr//> function in the first argument. For example:

  t_cmp(qr/^abc/, "abcd", "regex compare");

will do:

  "abcd" =~ /^abc/;

This function is exported by default.

=item t_debug()

  t_debug("testing feature foo");
  t_debug("test", [1..3], 5, {a=>[1..5]});

t_debug() prints out any datastructure while prepending C<#> at the
beginning of each line, to make the debug printouts comply with
C<Test::Harness>'s requirements. This function should be always used
for debug prints, since if in the future the debug printing will
change (e.g. redirected into a file) your tests won't need to be
changed.

This function is exported by default.

=item t_write_file()

  t_write_file($filename, @lines);

t_write_file() creates a new file at I<$filename> or overwrites the
existing file with the content passed in I<@lines>. If only the
I<$filename> is passed, an empty file will be created.

If parent directories of C<$filename> don't exist they will be
automagically created.

The generated file will be automatically deleted at the end of the
program's execution.

This function is exported by default.

=item t_append_file()

  t_append_file($filename, @lines);

t_append_file() is similar to t_write_file(), but it doesn't clobber
existing files and appends C<@lines> to the end of the file. If the
file doesn't exist it will create it.

If parent directories of C<$filename> don't exist they will be
automagically created.

The generated file will be registered to be automatically deleted at
the end of the program's execution, only if the file was created by
t_append_file().

This function is exported by default.

=item t_write_shell_script()

  Apache::TestUtil::t_write_shell_script($filename, @lines);

Similar to t_write_file() but creates a portable shell/batch
script. The created filename is constructed from C<$filename> and an
appropriate extension automatically selected according to the platform
the code is running under.

It returns the extension of the created file.

=item t_write_perl_script()

  Apache::TestUtil::t_write_perl_script($filename, @lines);

Similar to t_write_file() but creates a executable Perl script with
correctly set shebang line.

=item t_open_file()

  my $fh = t_open_file($filename);

t_open_file() opens a file I<$filename> for writing and returns the
file handle to the opened file.

If parent directories of C<$filename> don't exist they will be
automagically created.

The generated file will be automatically deleted at the end of the
program's execution.

This function is exported by default.

=item t_mkdir()

  t_mkdir($dirname);

t_mkdir() creates a directory I<$dirname>. The operation will fail if
the parent directory doesn't exist.

If parent directories of C<$dirname> don't exist they will be
automagically created.

The generated directory will be automatically deleted at the end of
the program's execution.

This function is exported by default.

=item t_rmtree()

  t_rmtree(@dirs);

t_rmtree() deletes the whole directories trees passed in I<@dirs>.

This function is exported by default.

=item t_chown()

  Apache::TestUtil::t_chown($file);

Change ownership of $file to the test's I<User>/I<Group>.  This
function is noop on platforms where chown(2) is unsupported
(e.g. Win32).

=item t_is_equal()

  t_is_equal($a, $b);

t_is_equal() compares any two datastructures and returns 1 if they are
exactly the same, otherwise 0. The datastructures can be nested
hashes, arrays, scalars, undefs or a combination of any of these.  See
t_cmp() for an example.

If C<$a> is a regex reference, the regex comparison C<$b =~ $a> is
performed. For example:

  t_is_equal(qr{^Apache}, $server_version);

If comparing non-scalars make sure to pass the references to the
datastructures.

This function is exported by default.

=item t_server_log_error_is_expected()

If the handler's execution results in an error or a warning logged to
the I<error_log> file which is expected, it's a good idea to have a
disclaimer printed before the error itself, so one can tell real
problems with tests from expected errors. For example when testing how
the package behaves under error conditions the I<error_log> file might
be loaded with errors, most of which are expected.

For example if a handler is about to generate a run-time error, this
function can be used as:

  use Apache::TestUtil;
  ...
  sub handler {
      my $r = shift;
      ...
      t_server_log_error_is_expected();
      die "failed because ...";
  }

After running this handler the I<error_log> file will include:

  *** The following error entry is expected and it is harmless ***
  [Tue Apr 01 14:00:21 2003] [error] failed because ...

If the error is generated at compile time, the logging must be done in
the BEGIN block at the very beginning of the file:

  BEGIN {
      use Apache::TestUtil;
      t_server_log_error_is_expected();
  }
  use DOES_NOT_exist;

After attempting to run this handler the I<error_log> file will
include:

  *** The following error entry is expected and it is harmless ***
  [Tue Apr 01 14:04:49 2003] [error] Can't locate "DOES_NOT_exist.pm"
  in @INC (@INC contains: ...

Also see C<t_server_log_warn_is_expected()> which is similar but used
for warnings.

This function is exported by default.

=item t_server_log_warn_is_expected()

C<t_server_log_warn_is_expected()> generates a disclaimer for expected
warnings.

See the explanation for C<t_server_log_error_is_expected()> for more
details.

This function is exported by default.

=item t_client_log_error_is_expected()

C<t_client_log_error_is_expected()> generates a disclaimer for
expected errors. But in contrast to
C<t_server_log_error_is_expected()> called by the client side of the
script.

See the explanation for C<t_server_log_error_is_expected()> for more
details.

For example the following client script fails to find the handler:

  use Apache::Test;
  use Apache::TestUtil;
  use Apache::TestRequest qw(GET);
  
  plan tests => 1;
  
  t_client_log_error_is_expected();
  my $url = "/error_document/cannot_be_found";
  my $res = GET($url);
  ok t_cmp(404, $res->code, "test 404");

After running this test the I<error_log> file will include an entry
similar to the following snippet:

  *** The following error entry is expected and it is harmless ***
  [Tue Apr 01 14:02:55 2003] [error] [client 127.0.0.1] 
  File does not exist: /tmp/test/t/htdocs/error

This function is exported by default.

=item t_client_log_warn_is_expected()

C<t_client_log_warn_is_expected()> generates a disclaimer for expected
warnings on the client side.

See the explanation for C<t_client_log_error_is_expected()> for more
details.

This function is exported by default.

=back

=head1 AUTHOR

Stas Bekman <stas@stason.org>

=head1 SEE ALSO

perl(1)

=cut

