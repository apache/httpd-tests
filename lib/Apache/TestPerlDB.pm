package Apache::TestPerlDB;

use strict;

sub lwpd {
    my $val = $_[0] || 1;
    if ($val =~ /^\d+$/) {
        $Apache::TestRequest::DebugLWP;
        print "\$Apache::TestRequest::DebugLWP = $val\n";
    }
    else {
        require LWP::Debug;
        LWP::Debug->import(@_);
        print "LWP::Debug->import(@_)\n";
    }
}

my %help = (
    lwpd => 'Set the LWP debug level for Apache::TestRequest',
);

my $setup_db_aliases = sub {
    my $package = __PACKAGE__;
    my @cmds;
    no strict 'refs';

    while (my($name, $val) = each %{"$package\::"}) {
        next unless defined &$val;
        *{"main::$name"} = \&{$val};
        push @cmds, $name;
    }

    print "$package added perldb commands:\n",
      map { "   $_ - $help{$_}\n" } @cmds;

};

$setup_db_aliases->();

1;
__END__
