use ExtUtils::MakeMaker;

use 5.005;

use lib qw(Apache-Test/lib);

use Apache::Test5005compat;

use Apache::TestMM qw(test clean);

use File::Find qw(finddepth);

my @scripts = qw(t/TEST t/SMOKE);

finddepth(sub {
    return unless /(.*?\.pl)\.PL$/;
    push @scripts, "$File::Find::dir/$1";
}, '.');

Apache::TestMM::filter_args();

for my $script (@scripts) {
    Apache::TestMM::generate_script($script);
}

WriteMakefile(
    NAME => 'httpd-test',
    VERSION => '0.01',
    clean => { FILES => "@scripts t/TEST" },
);
