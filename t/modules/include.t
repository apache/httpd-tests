use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## mod_include tests
my ($doc, $actual, $expected);
my $dir = "/modules/include/";

## 1: <!--#echo var="DOCUMENT_NAME" -->
## 2: <!--#set var="message" value="set works"-->
## 3: <!--#include file="inc-two.shtml"-->
## 4: <!--#include virtual="/modules/include/inc-two.shtml"-->
## 5: <!--#include file="inc-one.shtml"--> (which in turn includes inc-two)
## 6: <!--#include virtual="/modules/include/inc-one.shtml"-->
## 7: <!--#include file="inc-three.shtml"--> (which in turn includes two more)
## 8: <!--#include virtual="/modules/include/inc-one.shtml"-->
## 9: <!--#foo virtual="/inc-two.shtml"-->
## 10: <!--#include file="/inc-two.shtml"-->
## 11: <!--#include virtual="/inc-two.shtml"-->
## 12+: various tests for <!--#config errmsg="errmsg"-->

my %test = (
"echo.shtml"		=>	"echo.shtml\n",
"set.shtml"		=>	"\nset works\n",
"include1.shtml"	=>	"inc-two.shtml body\n\ninclude.shtml body\n",
"include2.shtml"	=>	"inc-two.shtml body\n\ninclude.shtml body\n",
"include3.shtml"	=>	"inc-two.shtml body\n\ninc-one.shtml body\n\ninclude.shtml body\n",
"include4.shtml"	=>	"inc-two.shtml body\n\ninc-one.shtml body\n\ninclude.shtml body\n",
"include5.shtml"	=>	"inc-two.shtml body\n\ninc-one.shtml body\n\ninc-three.shtml body\n\ninclude.shtml body\n",
"include6.shtml"	=>	"inc-two.shtml body\n\ninc-one.shtml body\n\ninc-three.shtml body\n\ninclude.shtml body\n",
"foo.shtml"		=>	"[an error occurred while processing this directive]\nfoo.shtml body\n",
"foo1.shtml"		=>	"[an error occurred while processing this directive]\nfoo.shtml body\n",
"foo2.shtml"		=>	"[an error occurred while processing this directive]\nfoo.shtml body\n",
"encode.shtml"		=>	"\n\# \%\^\n\%23\%20\%25\%5e\n",
"errmsg1.shtml"		=>	"\nerrmsg\n",
"errmsg2.shtml"		=>	"\nerrmsg\n",
"errmsg3.shtml"		=>	"\nerrmsg\n",
);

my $tests = keys %test;
plan tests => $tests;

my $bung = 0;
foreach (keys %test) {
	$doc = $_;
	$expected = $test{$_};
	$actual = GET_BODY "$dir$doc";
	unless ($actual eq $expected) {
		$bung++;
		open (FOO, ">bung$bung");
		print FOO "$_\n";
		print FOO "expected:\n->$expected<-\n";
		print FOO "actual:\n->$actual<-\n";
		close(FOO);
	}
	ok ($actual eq $expected);
}

