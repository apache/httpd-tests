use 5.005;

use ExtUtils::MakeMaker;

use lib qw(lib);

use Apache::Test5005compat;

use Apache::TestMM qw(test); #enable 'make test'

Apache::TestMM::filter_args();

my @scripts = qw(t/TEST);

for (@scripts) {
    Apache::TestMM::generate_script($_);
}

WriteMakefile(
    NAME         => 'Apache::Test',
    VERSION_FROM => 'lib/Apache/Test.pm',
    dist      => {
	COMPRESS => 'gzip -9f', SUFFIX=>'gz',
    },
);

