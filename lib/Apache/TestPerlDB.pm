#no 'package Apache::TestPerlDB.pm' here, else we change perldb's package
use strict;

sub Apache::TestPerlDB::lwpd {
    print Apache::TestRequest::lwp_debug(shift || 1);
}

my %help = (
    lwpd => 'Set the LWP debug level for Apache::TestRequest',
);

my $setup_db_aliases = sub {
    my $package = 'Apache::TestPerlDB';
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
