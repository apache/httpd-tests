use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

use constant WINFU => Apache::TestConfig::WINFU();

##
## mod_alias test
##

## redirect codes for Redirect testing ##
my %redirect = (
    perm     =>  '301',
    perm2    =>  '301',
    temp     =>  '302',
    temp2    =>  '302',
    seeother =>  '303',
    gone     =>  '410'
);

## RedirectMatch testing ##
my %rm_body = (
    p   =>  '301',
    t   =>  '302'
);

my %rm_rc = (
    s   =>  '303',
    g   =>  '410'
);

#XXX: find something that'll on other platforms (/bin/sh aint it)
my $script_tests = WINFU ? 0 : 4;

plan tests => (keys %redirect) + (keys %rm_body) * 10 + (keys %rm_rc) * 10 + 12 + $script_tests,
    have_module 'alias';

## simple alias ##
print "verifying simple aliases\n";
ok ('200' eq GET_RC "/alias/");
## alias to a non-existant area ##
ok ('404' eq GET_RC "/bogu/");


print "verifying alias match with /ali[0-9].\n";
for (my $i=0 ; $i <= 9 ; $i++) {
    ok ("$i" eq GET_BODY "/ali$i");
}

my ($actual, $expected);
foreach (sort keys %redirect) {
    ## make LWP not follow the redirect since we
    ## are just interested in the return code.
    local $Apache::TestRequest::RedirectOK = 0;

    $expected = $redirect{$_};
    $actual = GET_RC "/$_";
    print "$_: expect: $expected, got: $actual\n";
    ok ($actual eq $expected);
}

print "verifying body of perm and temp redirect match\n";
foreach (sort keys %rm_body) {
    for (my $i=0 ; $i <= 9 ; $i++) {
        $expected = $i;
        $actual = GET_BODY "/$_$i";
        ok ($actual eq $expected);
    }
}

print "verifying return code of seeother and gone redirect match\n";
foreach (keys %rm_rc) {
    $expected = $rm_rc{$_};
    for (my $i=0 ; $i <= 9 ; $i++) {
        $actual = GET_RC "$_$i";
        ok ($actual eq $expected);
    }
}

## create a little cgi to test ScriptAlias and ScriptAliasMatch ##
my $string = "this is a shell script cgi.";
my $cgi =<<EOF;
#!/bin/sh
echo Content-type: text/plain
echo
echo $string
EOF

my $vars = Apache::Test::vars();
my $script = "$vars->{t_dir}/htdocs/modules/alias/script";

t_write_file($script,$cgi);
chmod 0755, $script;

## if we get the script here it will be plain text ##
print "verifying /modules/alias/script is plain text\n";
ok ($cgi eq GET_BODY "/modules/alias/script") unless WINFU;

## here it should be the result of the executed cgi ##
print "verifying same file accessed at /cgi/script is executed code\n";
ok ("$string\n" eq GET_BODY "/cgi/script") unless WINFU;
## with ScriptAliasMatch ##
print "verifying ScriptAliasMatch with /aliascgi-script\n";
ok ("$string\n" eq GET_BODY "/aliascgi-script") unless WINFU;

## failure with ScriptAliasMatch ##
print "verifying bad script alias.\n";
ok ('404' eq GET_RC "/aliascgi-nada") unless WINFU;

## clean up ##
t_rmtree("$vars->{t_logs}/mod_cgi.log");
