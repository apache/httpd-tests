use ExtUtils::MakeMaker;

use lib qw(Apache-Test/lib);
use Apache::TestMM qw(test);

Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(
    NAME => 'httpd-test',
    VERSION => '0.01',
);
