use 5.006;

use ExtUtils::MakeMaker;

use lib qw(lib);

use Apache::TestMM qw(test); #enable 'make test'

my @scripts = qw(t/TEST);

for (@scripts) {
    Apache::TestMM::generate_script($_);
}

WriteMakefile(
    NAME         => 'Apache::Test',
    VERSION_FROM => 'lib/Apache/Test.pm',
);

