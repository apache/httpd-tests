use ExtUtils::MakeMaker;

use 5.006;

use lib qw(Apache-Test/lib);
use Apache::TestMM qw(test clean);

use File::Find qw(finddepth);

my @scripts;

finddepth(sub {
    return unless /(.*?\.pl)\.PL$/;
    push @scripts, "$File::Find::dir/$1";
}, '.');

for my $script (@scripts) {
    Apache::TestMM::generate_script($script);
}

Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(
    NAME => 'httpd-test',
    VERSION => '0.01',
    clean => { FILES => "@scripts t/TEST" },
);
