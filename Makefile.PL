use 5.006;

use ExtUtils::MakeMaker;

use lib qw(lib);

use Apache::TestMM qw(test); #enable 'make test'

WriteMakefile(NAME => 'Apache::Test',
              VERSION_FROM => 'lib/Apache/Test.pm');
