use ExtUtils::MakeMaker;

use 5.005;

use lib qw(Apache-Test/lib);

use Apache::Test5005compat;

use Apache::TestMM qw(test clean);
use Apache::TestReport ();
use Apache::TestSmoke ();
use Apache::TestRun ();

use File::Find qw(finddepth);

my @scripts = ();

finddepth(sub {
    return unless /(.*?\.pl)\.PL$/;
    push @scripts, "$File::Find::dir/$1";
}, '.');

Apache::TestMM::filter_args();

for my $script (@scripts) {
    Apache::TestMM::generate_script($script);
}

for my $util (qw(Report Smoke Run)) {
    my $class = "Apache::Test${util}";
    $class->generate_script;
}

WriteMakefile(
    NAME => 'httpd-test',
    VERSION => '0.01',
    clean => { FILES => "@scripts" },
);
