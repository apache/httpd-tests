use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## mod_negotiation test
##
## extra.conf.in:
##
## <IfModule mod_mime.c>
## AddLanguage en .en
## AddLanguage fr .fr
## AddLanguage de .de
## AddLanguage fu .fu
## AddHandler type-map .var
## 
## <IfModule mod_negotiation.c>
## CacheNegotiatedDocs
## <Directory @SERVERROOT@/htdocs/modules/negotiation/en>
## Options +MultiViews
## LanguagePriority en fr de fu
## </Directory>
## <Directory @SERVERROOT@/htdocs/modules/negotiation/de>
## Options +MultiViews
## LanguagePriority de en fr fu
## </Directory>
## <Directory @SERVERROOT@/htdocs/modules/negotiation/fr>
## Options +MultiViews
## LanguagePriority fr en de fu
## </Directory>
## <Directory @SERVERROOT@/htdocs/modules/negotiation/fu>
## Options +MultiViews
## LanguagePriority fu fr en de
## </Directory>
## </IfModule>
## </IfModule>


my ($en, $fr, $de, $fu, $bu) = qw(en fr de fu bu);
my @language = ($en, $fr, $de, $fu);

plan tests => (@language * 3) + (@language * @language * 5) + 6,
    have_module 'negotiation';

my $actual;
foreach (@language) {

    ## verify that the correct default language content is returned
    $actual = GET_BODY "/modules/negotiation/$_/";
    chomp $actual;
    ok ($actual eq "index.html.$_");

    $actual = GET_BODY "/modules/negotiation/$_/compressed/";
    chomp $actual;
    ok ($actual eq "index.html.$_.gz");

    $actual = GET_BODY "/modules/negotiation/$_/two/index";
    chomp $actual;
    ok ($actual eq "index.$_.html");

    foreach my $ext (@language) {

        ## verify that you can explicitly request all language files.
        ok GET_OK "/modules/negotiation/$_/index.html.$ext";
        ok GET_OK "/modules/negotiation/$_/two/index.$ext.html";

        ## verify that even tho there is a default language,
        ## the Accept-Language header is obeyed when present.
        $actual = GET_BODY "/modules/negotiation/$_/",
            'Accept-Language' => $ext;
        chomp $actual;
        ok ($actual eq "index.html.$ext");

        $actual = GET_BODY "/modules/negotiation/$_/compressed/",
            'Accept-Language' => $ext;
        chomp $actual;
        ok ($actual eq "index.html.$ext.gz");

        $actual = GET_BODY "/modules/negotiation/$_/two/index",
            'Accept-Language' => $ext;
        chomp $actual;
        ok ($actual eq "index.$ext.html");

    }
}

## more complex requests ##

## 'fu' has a quality rating of 0.9 which is higher than the rest
## we expect Apache to return the 'fu' content.
$actual = GET_BODY "/modules/negotiation/$en/",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $fu; q=0.9, $de; q=0.2";
chomp $actual;
ok ($actual eq "index.html.$fu");

$actual = GET_BODY "/modules/negotiation/$en/two/index",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $fu; q=0.9, $de; q=0.2";
chomp $actual;
ok ($actual eq "index.$fu.html");

$actual = GET_BODY "/modules/negotiation/$en/compressed/",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $fu; q=0.9, $de; q=0.2";
chomp $actual;
ok ($actual eq "index.html.$fu.gz");

## 'bu' has the highest quality rating, but is non-existant,
## so we expect the next highest rated 'fr' content to be returned.
$actual = GET_BODY "/modules/negotiation/$en/",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $bu; q=1.0";
chomp $actual;
ok ($actual eq "index.html.$fr");

$actual = GET_BODY "/modules/negotiation/$en/two/index",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $bu; q=1.0";
chomp $actual;
ok ($actual eq "index.$fr.html");

$actual = GET_BODY "/modules/negotiation/$en/compressed/",
    'Accept-Language' => "$en; q=0.1, $fr; q=0.4, $bu; q=1.0";
chomp $actual;
ok ($actual eq "index.html.$fr.gz");
