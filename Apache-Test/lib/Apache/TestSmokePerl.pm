package Apache::TestSmokePerl;

use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::TestSmoke ();
use ModPerl::Config ();

use File::Spec::Functions qw(catfile);

# a subclass of Apache::TestSmoke that configures mod_perlish things
use vars qw(@ISA);
@ISA = qw(Apache::TestSmoke);

# generate t/SMOKE script (or a different filename) which will drive
# Apache::TestSmokePerl
sub generate_script {
    my ($class, $file) = @_;

    $file ||= catfile 't', 'SMOKE';

    my $content = <<'EOM';
use strict;
use warnings FATAL => 'all';

use FindBin;
use lib "$FindBin::Bin/../Apache-Test/lib";
use lib "$FindBin::Bin/../lib";

use Apache::TestSmokePerl ();

Apache::TestSmokePerl->new(@ARGV)->run;
EOM

    Apache::Test::config()->write_perlscript($file, $content);

}

sub build_config_as_string {
    my($self) = @_;

    return ModPerl::Config::as_string();
}

1;
__END__

