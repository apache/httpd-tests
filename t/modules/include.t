use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

use constant WINFU => Apache::TestConfig::WINFU;

## mod_include tests
my($res, $str, $doc);
my $dir = "/modules/include/";
my $have_apache_2 = have_apache 2;
my $vars = Apache::Test::vars();
my $docroot = $vars->{documentroot};


my %test = (
"echo.shtml"            =>    "echo.shtml",
"set.shtml"             =>    "set works",
"include1.shtml"        =>    "inc-two.shtml body  include.shtml body",
"include2.shtml"        =>    "inc-two.shtml body  include.shtml body",
"include3.shtml"        =>
    "inc-two.shtml body  inc-one.shtml body  include.shtml body",
"include4.shtml"        =>
    "inc-two.shtml body  inc-one.shtml body  include.shtml body",
"include5.shtml"        =>
    "inc-two.shtml body  inc-one.shtml body  inc-three.shtml body  include.shtml body",
"include6.shtml"        =>
    "inc-two.shtml body  inc-one.shtml body  inc-three.shtml body  include.shtml body",
"foo.shtml"             =>
    "[an error occurred while processing this directive] foo.shtml body",
"foo1.shtml"            =>
    "[an error occurred while processing this directive] foo.shtml body",
"foo2.shtml"            =>
    "[an error occurred while processing this directive] foo.shtml body",
"encode.shtml"          =>    "\# \%\^ \%23\%20\%25\%5e",
"errmsg1.shtml"         =>    "errmsg",
"errmsg2.shtml"         =>    "errmsg",
"errmsg3.shtml"         =>    "errmsg",
"errmsg4.shtml"         =>    $have_apache_2 ? "pass errmsg" : "pass",
"errmsg5.shtml"         =>    "<!-- pass -->",
"if1.shtml"             =>    "pass",
"if2.shtml"             =>    "pass   pass",
"if3.shtml"             =>    "pass   pass   pass",
"if4.shtml"             =>    "pass   pass",
"if5.shtml"             =>    "pass  pass  pass",
"big.shtml"             =>    "hello   pass  pass   pass     hello",
"newline.shtml"         =>    "inc-two.shtml body",
"inc-rfile.shtml"       =>
    "inc-extra2.shtml body  inc-extra1.shtml body  inc-rfile.shtml body",
"inc-rvirtual.shtml"    =>
    "inc-extra2.shtml body  inc-extra1.shtml body  inc-rvirtual.shtml body",
"extra/inc-bogus.shtml" =>
    "[an error occurred while processing this directive] inc-bogus.shtml body",
"abs-path.shtml"        =>
    "inc-extra2.shtml body  inc-extra1.shtml body  abs-path.shtml body",
"exec/off/cmd.shtml"    =>
    "[an error occurred while processing this directive]",
"exec/on/cmd.shtml"     =>    "pass",
"notreal.shtml"         =>    "pass <!--",
"parse1.shtml"          =>    "-->",
"parse2.shtml"          =>    "\""
);

#this test does not work on win32 (<!--#exec cmd="echo pass"-->)
if (WINFU) {
    delete $test{'exec/on/cmd.shtml'};
}

# 1.3 gets slightly modified versions, since it cannot parse some files
# written for 2.x (requires spaces before end_seq)
if ($have_apache_2) {
    $test{"if8.shtml"}   = "pass";
    $test{"if9.shtml"}   = "pass   pass";
    $test{"if10.shtml"}  = "pass";

    # regex captures are 2.x only
    $test{"regex.shtml"} = "(none)  1 (none)";
}
else {
    $test{"if8a.shtml"}  = "pass";
    $test{"if9a.shtml"}  = "pass   pass";
    $test{"if10a.shtml"} = "pass";
}

my %t_test = ();
if ($have_apache_2) {
    %t_test =
    (
        "echo.shtml"      => ['<!--#echo var="DOCUMENT_NAME" -->', "retagged1"], 
        "retagged1.shtml" => ["retagged1.shtml",                   "retagged1"],
        "retagged2.shtml" => ["----retagged2.shtml",               "retagged1"],
    );
}

my @patterns = (
    'mod_include test',
    'Hello World',
    'footer',
);

#
# in addition to $tests, there are 1 fsize/flastmod test, 1 GET test,
# 11 XBitHack tests, 2 exec cgi tests, 2 malformed-ssi-directive tests,
# and 14 tests that use mod_bucketeer to construct brigades for mod_include
#
my $tests = scalar(keys %test) + scalar(keys %t_test) + @patterns + 2;
plan tests => $tests + 31, have_module 'include';

Apache::TestRequest::scheme('http'); #ssl not listening on this vhost
Apache::TestRequest::module('mod_include'); #use this module's port

foreach $doc (sort keys %test) {
    ok t_cmp($test{$doc},
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );
}

$doc = "printenv.shtml";
ok t_cmp("200",
         GET("$dir$doc")->code,
         "GET $dir$doc"
        );


### MALFORMED DIRECTIVE TESTS
# also test a couple of malformed SSIs that used to cause Apache 1.3 to
# segfault
#

# Apache 1.3 has a different parser so you get different output (ie, none)
my $expected = ($have_apache_2)
                 ? "[an error occurred while processing this directive]"
                 : "";

ok t_cmp("$expected",
         super_chomp(GET_BODY "${dir}if6.shtml"),
         "GET ${dir}if6.shtml"
        );


$expected = ($have_apache_2)
                 ? "[an error occurred while processing this directive]"
                 : "";

ok t_cmp("$expected",
         super_chomp(GET_BODY "${dir}if7.shtml"),
         "GET ${dir}if7.shtml"
        );

### FLASTMOD/FSIZE TESTS
unless(eval{require POSIX}) {
    skip "POSIX module not found", 1;
}
else {
    my ($size, $mtime) = (stat "$docroot${dir}file.shtml")[7, 9];
    my @time = localtime($mtime);
    
    my $strftime = sub($) {
        my $fmt = shift;

        POSIX::strftime($fmt, $time[0], $time[1], $time[2], $time[3], $time[4],
                        $time[5], -1, -1, -1);
    };

    # XXX: not sure about the locale thing, but it seems to work at least on my
    # machine :)
    POSIX->import('locale_h');
    my $oldloc = setlocale(&LC_TIME);
    POSIX::setlocale(&LC_TIME, "C");

    $expected = join ' ' =>
        $strftime->("%A, %d-%b-%Y %H:%M:%S %Z"),
        $strftime->("%A, %d-%b-%Y %H:%M:%S %Z"),
        $strftime->("%A, %B %e, %G"),
        $strftime->("%A, %B %e, %G"),
        $strftime->("%T"),
        $strftime->("%T");

    # XXX: works, because file.shtml is very small.
    $expected .= " $size $size $size $size";

    POSIX::setlocale(&LC_TIME, $oldloc);

    $expected =~ s/\s+/ /g;
    $expected =~ s/ $//; $expected =~ s/^ //;

    my $result = super_chomp(GET_BODY "${dir}file.shtml");
    $result =~ s/\s+/ /g;
    $result =~ s/ $//; $result =~ s/^ //;

    ok t_cmp("$expected",
             "$result",
             "GET ${dir}file.shtml"
            );
}

### EXEC CGI TESTS
# skipped if !have_cgi
my %execcgitest = (
"exec/off/cgi.shtml" =>
    "[an error occurred while processing this directive]",
"exec/on/cgi.shtml" =>
    "perl cgi"
);
foreach $doc (sort keys %execcgitest) {
    if (have_cgi()) {
        ok t_cmp($execcgitest{$doc},
                 super_chomp(GET_BODY "$dir$doc"),
                 "GET $dir$doc"
                );
    }
    else {
        skip "Skipping 'exec cgi' test; no cgi module.", 1;
    }
}

if (WINFU) {
    for (1..11) {
        skip "Skipping XBitHack tests on this platform", 1;
    }
}
else {
    ### XBITHACK TESTS
    # test xbithack off
    $doc = "xbithack/off/test.html";
    foreach ("0444", "0544", "0554") {
        chmod oct($_), "htdocs/$dir$doc";
        ok t_cmp("<BODY> <!--#include virtual=\"../../inc-two.shtml\"--> </BODY>",
                 super_chomp(GET_BODY "$dir$doc"),
                 "XBitHack off [$_]"
                );
    }

    # test xbithack on
    $doc = "xbithack/on/test.html";
    chmod 0444, "htdocs$dir$doc";
    ok t_cmp("<BODY> <!--#include virtual=\"../../inc-two.shtml\"--> </BODY>",
             super_chomp(GET_BODY "$dir$doc"),
             "XBitHack on [0444]"
            );

    foreach ("0544", "0554") {
        chmod oct($_), "htdocs/$dir$doc";
        ok t_cmp("No Last-modified date ; <BODY> inc-two.shtml body  </BODY>",
                 check_xbithack(GET "$dir$doc"),
                 "XBitHack on [$_]"
                );
    }

    # test xbithack full
    $doc = "xbithack/full/test.html";
    chmod 0444, "htdocs/$dir$doc";
    ok t_cmp("<BODY> <!--#include virtual=\"../../inc-two.shtml\"--> </BODY>",
             super_chomp(GET_BODY "$dir$doc"),
             "XBitHack full [0444]"
            );
    chmod 0544, "htdocs/$dir$doc";
    ok t_cmp("No Last-modified date ; <BODY> inc-two.shtml body  </BODY>",
             check_xbithack(GET "$dir$doc"),
             "XBitHack full [0544]"
            );

    my $lm;

    chmod 0554, "htdocs/$dir$doc";
    ok t_cmp("Has Last-modified date ; <BODY> inc-two.shtml body  </BODY>",
             check_xbithack(GET("$dir$doc"), \$lm),
             "XBitHack full [0554]"
            );

    ok t_cmp(304, GET("$dir$doc", 'If-Modified-Since' => $lm)->code,
             "XBitHack full [0554] / If-Modified-Since"
            );

    chmod 0544, "htdocs/$dir$doc";
    ok t_cmp(200, GET("$dir$doc", 'If-Modified-Since' => $lm)->code,
             "XBitHack full [0544] / If-Modified-Since"
            );
}

### test include + query string
$res = GET "${dir}virtual.shtml";

ok $res->is_success;

$str = $res->content;

ok $str;

for my $pat (@patterns) {
    ok t_cmp(qr{$pat}, $str, "/$pat/");
}

### Simple tests for SSI(Start|End)Tags that differ from default
if ($have_apache_2) {
    for (sort keys %t_test) {
        ok t_cmp($t_test{$_}[0],
                 super_chomp(GET_BODY "$dir$_", Host => $t_test{$_}[1]),
                 "GET $dir$_"
                );
    }
}

### MOD_BUCKETEER+MOD_INCLUDE TESTS
# we can use mod_bucketeer to create edge conditions for mod_include, since
# it allows us to create bucket and brigade boundaries wherever we want
if (have_module 'mod_bucketeer') {

    $expected = "____ _____ _____ ___________________ </table>  ".
                "##################################1/8</tr> ".
                "##################################2/8</tr> ".
                "##################################3/8</tr> ".
                "##################################4/8</tr> ".
                "##################################5/8</tr> ".
                "##################################6/8$docroot</tr> ".
                "##################################7/8</tr> ".
                "##################################8/8</tr> ".
                "@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@";

    $doc = "bucketeer/y.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected = "____ ___________________________________".
                "________________________________________".
                "___ ____________________________________".
                "________________________________________".
                "__________ ___________________ </table>  ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "#####################################</tr> ".
                "@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@";

    for (0..3) {
        $doc = "bucketeer/y$_.shtml";
        my ($body) = super_chomp(GET_BODY "$dir$doc");
        $body =~ s/\002/^B/g;
        $body =~ s/\006/^F/g;
        $body =~ s/\020/^P/g;
        ok t_cmp($expected,
                 $body,
                 "GET $dir$doc"
                );
    }

    $expected = "[an error occurred while processing this directive]";
    $doc = "bucketeer/y4.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );


    $expected= "pass [an error occurred while processing this directive]  ".
               "pass pass1";
    $doc = "bucketeer/y5.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected= "BeforeIfElseBlockAfterIf";
    $doc = "bucketeer/y6.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected= "Before If <!-- comment -->SomethingElse".
               "<!-- right after if -->After if";
    $doc = "bucketeer/y7.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected= "FalseSetDone";
    $doc = "bucketeer/y8.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected= "FalseSetDone";
    $doc = "bucketeer/y9.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    $expected= "\"pass\"";
    $doc = "bucketeer/y10.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc"),
             "GET $dir$doc"
            );

    ### exotic SSI(Start|End)Tags

    $expected= "----retagged3.shtml";
    $doc = "bucketeer/retagged3.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc", Host => 'retagged1'),
             "GET $dir$doc"
            );

    $expected= "---pass";
    $doc = "bucketeer/retagged4.shtml";
    ok t_cmp($expected,
             super_chomp(GET_BODY "$dir$doc", Host => 'retagged2'),
             "GET $dir$doc"
            );
}
else {
    for (1..14) {
        skip "Skipping bucket boundary tests, no mod_bucketeer", 1;
    }
}

sub super_chomp {
    my ($body) = shift;

    ## super chomp - all leading and trailing \n (and \r for win32)
    $body =~ s/^[\n\r]*//;
    $body =~ s/[\n\r]*$//;
    ## and all the rest change to spaces
    $body =~ s/\n/ /g;
    $body =~ s/\r//g; #rip out all remaining \r's

    $body;
}

sub check_xbithack {
    my ($resp) = shift;
    my ($body) = super_chomp($resp->content);
    my ($lastmod) = ($resp->last_modified)
                      ? "Has Last-modified date" : "No Last-modified date";

    my $data = shift;
    $$data = $resp->header('Last-Modified') if $data;

    "$lastmod ; $body";
}
