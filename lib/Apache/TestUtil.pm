package Apache::TestUtil;

use strict;
use warnings FATAL => 'all';

use File::Find ();
use File::Path ();
use Exporter ();

our $VERSION = '0.01';
our @ISA     = qw(Exporter);
our @EXPORT  = qw(t_cmp t_write_file t_open_file t_mkdir t_rmtree);

our %CLEAN = ();

sub t_cmp {
    my ($expected, $received, $comment) = @_;
    print "testing : $comment\n" if defined $comment;
    print "expected: " . (defined $expected ? $expected : "undef") . "\n";
    print "received: " . (defined $received ? $received : "undef") . "\n";
    defined $expected && defined $received && $expected eq $received;
}

sub t_write_file {
    my $file = shift;
    die "must pass a filename" unless defined $file;
    open my $fh, ">", $file or die "can't open $file: $!";
    print "writing file: $file\n";
    print $fh join '', @_ if @_;
    close $fh;
    $CLEAN{files}{$file}++;
}

sub t_open_file {
    my $file = shift;
    die "must pass a filename" unless defined $file;
    open my $fh, ">", $file or die "can't open $file: $!";
    print "writing file: $file\n";
    $CLEAN{files}{$file}++;
    return $fh;
}

sub t_mkdir {
    my $dir = shift;
    die "must pass a dirname" unless defined $dir;
    mkdir $dir, 0755 unless -d $dir;
    print "creating dir: $dir\n";
    $CLEAN{dirs}{$dir}++;
}

sub t_rmtree {
    die "must pass a dirname" unless defined $_[0];
    File::Path::rmtree((@_ > 1 ? \@_ : $_[0]), 0, 1);
}

END{

    # remove files that were created via this package
    for (grep {-e $_ && -f _ } keys %{ $CLEAN{files} } ) {
        print "removing file: $_\n";
        unlink $_;
    }

    # remove dirs that were created via this package
    for (grep {-e $_ && -d _ } keys %{ $CLEAN{dirs} } ) {
        print "removing dir tree: $_\n";
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

=item t_write_file()

  t_write_file($filename, @lines);

t_write_file() creates a new file at I<$filename> or overwrites the
existing file with the content passed in I<@lines>. If only the
I<$filename> is passed, an empty file will be created.

The generated file will be automatically deleted at the end of the
program's execution.

=item t_open_file()

  my $fh = t_open_file($filename);

t_open_file() opens a file I<$filename> for writing and returns the
file handle to the opened file.

The generated file will be automatically deleted at the end of the
program's execution.

=item t_mkdir()

  t_mkdir($dirname);

t_mkdir() creates a directory I<$dirname>. The operation will fail if
the parent directory doesn't exist.

META: should we use File::Path::mkpath() to generate any dir even if
the parent doesn't exist? or should we create t_mkpath() in addition?

The generated directory will be automatically deleted at the end of
the program's execution.

=item t_rmtree()

  t_rmtree(@dirs);

t_rmtree() deletes the whole directories trees passed in I<@dirs>.

=back

=head1 AUTHOR

Stas Bekman <stas@stason.org>

=head1 SEE ALSO

perl(1)


=cut

