%Apache::TestItSelf::Config = (
    perl_exec     => '/home/stas/perl/5.8.5-ithread/bin/perl5.8.5',
    mp_gen        => '2.0',
    httpd_gen     => '2.0',
    httpd_version => 'Apache/2.0.53-dev',
    timeout       => 900, # make test may take a long time
    makepl_arg    => '-libmodperl mod_perl-5.8.5-ithread.so',
    test_verbose  => 0,
);

my $path = '/home/stas/httpd';
my $common_makepl_arg = "MP_INST_APACHE2=1 MP_MAINTAINER=1";

@Apache::TestItSelf::Configs = ();
for (qw(prefork worker)) {
    push @Apache::TestItSelf::Configs,
        {
         apxs_exec     => "$path/$_/bin/apxs",
         httpd_exec    => "$path/$_/bin/httpd",
         httpd_conf    => "$path/$_/conf/httpd.conf",
         httpd_mpm     => "$_",
         makepl_arg    => "MP_APXS=$path/$_/bin/apxs $common_makepl_arg",
        };
}

1;
