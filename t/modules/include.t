use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

## mod_include tests
my ($doc);
my $dir = "/modules/include/";

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
"if1.shtml"             =>    "pass",
"if2.shtml"             =>    "pass   pass",
"if3.shtml"             =>    "pass   pass   pass",
"if4.shtml"             =>    "pass   pass",
"if5.shtml"             =>    "pass  pass  pass",
"big.shtml"             =>    "hello   pass  pass   pass     hello",
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
"exec/on/cmd.shtml"     =>    "pass"
);

#
# in addition to $tests, there is 1 GET test, 9 XBitHack tests,
# and 2 exec cgi tests
#
my $tests = keys %test;
plan tests => $tests + 12, have_module 'include';

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
chmod 0554, "htdocs/$dir$doc";
ok t_cmp("Has Last-modified date ; <BODY> inc-two.shtml body  </BODY>",
         check_xbithack(GET "$dir$doc"),
         "XBitHack full [0554]"
        );


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
    "$lastmod ; $body";
}
