use ExtUtils::MakeMaker;

use lib qw(Apache-Test/lib);
use Apache::TestMM qw(test);

my $htdocs  = 't/htdocs';
my $modules = "$htdocs/modules";
my $cgi     = "$modules/cgi";
my $rewrite = "$modules/rewrite";

my @cgi_scripts = map { "$cgi/$_" } qw{
perl_echo.pl bogus1k.pl perl.pl bogus-perl.pl
};

my @rewrite_scripts = map { "$rewrite/$_" } qw{
db.pl numbers.pl numbers2.pl
};

my @scripts = (@cgi_scripts, @rewrite_scripts);

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
