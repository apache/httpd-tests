use ExtUtils::MakeMaker;

use lib qw(Apache-Test/lib);
use Apache::TestMM qw(test);

my $htdocs  = 't/htdocs';
my $modules = "$htdocs/modules";
my $cgi     = "$modules/cgi";

my @cgi_scripts = map { "$cgi/$_" } qw(perl_echo.pl);

my @scripts = @cgi_scripts;

for my $script (@scripts) {
    Apache::TestMM::generate_script($script);
}

Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(
    NAME => 'httpd-test',
    VERSION => '0.01',
);
