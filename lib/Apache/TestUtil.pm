package Apache::TestUtil;

use strict;
use warnings FATAL => 'all';

use File::Find ();
use File::Path ();
use Exporter ();

use vars qw($VERSION @ISA @EXPORT %CLEAN);

$VERSION = '0.01';
@ISA     = qw(Exporter);
@EXPORT = qw(t_cmp t_write_file t_open_file t_mkdir t_rmtree
             t_is_equal);

%CLEAN = ();

use constant HAS_DUMPER => eval { require Data::Dumper; };
use constant INDENT     => 4;

sub t_cmp {
    die join(":", (caller)[1..2]) . 
        ' usage: $res = t_cmp($expected, $received, [$comment])'
            if @_ < 2 || @_ > 3;

    print "# testing : ", pop, "\n" if @_ == 3;
    print "# expected: ", struct_as_string(0, $_[0]), "\n";
    print "# received: ", struct_as_string(0, $_[1]), "\n";
    return t_is_equal(@_);
}

sub t_write_file {
    my $file = shift;
    die "must pass a filename" unless defined $file;
    my $fh = Symbol::gensym();
    open $fh, ">$file" or die "can't open $file: $!";
    print "# writing file: $file\n";
    print $fh join '', @_ if @_;
    close $fh;
    $CLEAN{files}{$file}++;
}

sub t_open_file {
    my $file = shift;
    die "must pass a filename" unless defined $file;
    my $fh = Symbol::gensym();
    open $fh, ">$file" or die "can't open $file: $!";
    print "# writing file: $file\n";
    $CLEAN{files}{$file}++;
    return $fh;
}

sub write_shell_script {
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

sub t_mkdir {
    my $dir = shift;
    die "must pass a dirname" unless defined $dir;
    mkdir $dir, 0755 unless -d $dir;
    print "# creating dir: $dir\n";
    $CLEAN{dirs}{$dir}++;
}

sub t_rmtree {
    die "must pass a dirname" unless defined $_[0];
    File::Path::rmtree((@_ > 1 ? \@_ : $_[0]), 0, 1);
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
            #t_cmp(qr{^Apache}, $server_version)
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

END{

    # remove files that were created via this package
    for (grep {-e $_ && -f _ } keys %{ $CLEAN{files} } ) {
        print "# removing file: $_\n";
        unlink $_;
    }

    # remove dirs that were created via this package
    for (grep {-e $_ && -d _ } keys %{ $CLEAN{dirs} } ) {
        print "# removing dir tree: $_\n";
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

  testing : 1 == 1?
  expected: 1
  received: 1

then it returns the result of comparison of the I<$expected> and the
I<$received> variables. Usually, the return value of this function is
fed directly to the ok() function, like this:

  ok t_cmp(1, 1, "1 == 1?");

the third argument (I<$comment>) is optional, but a nice to use.

It is valid to use I<undef> as an expected value. Therefore:

  1 == t_cmp(undef, undef, "undef == undef?");

is true.

You can compare any two data-structures with t_cmp(). Just make sure
that if you pass non-scalars, you have to pass their references. The
datastructures can be deeply nested. For example you can compare:

  t_cmp({1 => [2..3,{5..8}], 4 => [5..6]},
        {1 => [2..3,{5..8}], 4 => [5..6]},
        "hash of array of hashes");

This function is automatically exported.

=item t_write_file()

  t_write_file($filename, @lines);

t_write_file() creates a new file at I<$filename> or overwrites the
existing file with the content passed in I<@lines>. If only the
I<$filename> is passed, an empty file will be created.

The generated file will be automatically deleted at the end of the
program's execution.

This function is automatically exported.

=item write_shell_script()

write_shell_script($filename, @lines);

Similar to t_write_file() but creates a portable shell/batch
script. The created filename is constructed from C<$filename> and an
appropriate extension automatically selected according to the platform
the code is running under.

It returns the extension of the created file.

=item t_open_file()

  my $fh = t_open_file($filename);

t_open_file() opens a file I<$filename> for writing and returns the
file handle to the opened file.

The generated file will be automatically deleted at the end of the
program's execution.

This function is automatically exported.

=item t_mkdir()

  t_mkdir($dirname);

t_mkdir() creates a directory I<$dirname>. The operation will fail if
the parent directory doesn't exist.

META: should we use File::Path::mkpath() to generate any dir even if
the parent doesn't exist? or should we create t_mkpath() in addition?

The generated directory will be automatically deleted at the end of
the program's execution.

This function is automatically exported.

=item t_rmtree()

  t_rmtree(@dirs);

t_rmtree() deletes the whole directories trees passed in I<@dirs>.

This function is automatically exported.

=item t_is_equal()

  t_is_equal($a, $b);

t_is_equal() compares any two datastructures and returns 1 if they are
exactly the same, otherwise 0. The datastructures can be nested
hashes, arrays, scalars, undefs or a combination of any of these. See
t_cmp() for more examples.

If comparing non-scalars make sure to pass the references to the
datastructures.

This function is automatically exported.

=back

=head1 AUTHOR

Stas Bekman <stas@stason.org>

=head1 SEE ALSO

perl(1)

=cut

