package Apache::TestUtil;

use strict;
use warnings FATAL => 'all';
use File::Find ();
use File::Path ();
use Exporter ();

our $VERSION = '0.01';
our @ISA     = qw(Exporter);
our @EXPORT  = qw(t_cmp t_write_file t_open_file t_mkdir t_rm_tree);

our %CLEAN = ();

# t_cmp($expect,$received,$comment)
# returns the result of comparison of $expect and $received
# first prints all the arguments for debug.
##################
sub t_cmp {
    my ($expect, $received, $comment) = @_;
    print "testing : $comment\n" if defined $comment;
    print "expected: $expect\n";
    print "received: $received\n";
    $expect eq $received;
}

# t_write_file($filename,@lines);
# the file will be deleted at the end of the tests run
#################
sub t_write_file {
    my $file = shift;
    open my $fh, ">", $file or die "can't open $file: $!";
    print "writing file: $file\n";
    print $fh join '', @_ if @_;
    close $fh;
    $CLEAN{files}{$file}++;
}

# t_open_file($filename);
# open a file for writing and return the open fh
# the file will be deleted at the end of the tests run
################
sub t_open_file {
    my $file = shift;
    open my $fh, ">", $file or die "can't open $file: $!";
    print "writing file: $file\n";
    $CLEAN{files}{$file}++;
    return $fh;
}

# t_mkdir($dirname)
# create a dir
# the dir will be deleted at the end of the tests run
############
sub t_mkdir {
    my $dir = shift;

    mkdir $dir, 0755 unless -d $dir;
    print "creating dir: $dir\n";
    $CLEAN{dirs}{$dir}++;
}

# deletes the whole tree(s) or just file(s)
# accepts a list of dirs to delete
###############
sub t_rm_tree {
    File::Path::rmtree((@_ > 1 ? \@_ : $_[0]), 0, 1);
}

END{

    # cleanup first files than dirs
    map { unlink $_     } grep {-e $_ && -f _ } keys %{ $CLEAN{files} };
    map { t_rm_tree($_) } grep {-e $_ && -d _ } keys %{ $CLEAN{dirs}  };

}

1;
__END__


=head1 NAME

Apache::TestUtil - Utilities for writing tests

=head1 SYNOPSIS



=head1 DESCRIPTION



=cut

