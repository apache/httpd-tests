use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use ExtModules::TestEnv;

plan tests => 1, \&ExtModules::TestEnv::has_php4;

## dirname.php source:
## <?php
## 
##         function check_dirname($path)
##         {
##                 print "dirname($path) == " . dirname($path) . "\n";
##         }
## 
##         check_dirname("/foo/");
##         check_dirname("/foo");
##         check_dirname("/foo/bar");
##         check_dirname("d:\\foo\\bar.inc");
##         check_dirname("/");
##         check_dirname(".../foo");
##         check_dirname("./foo");
##         check_dirname("foobar///");
##         check_dirname("c:\foo");
## ?>
## 
## result should be:
## dirname(/foo/) == /
## dirname(/foo) == /
## dirname(/foo/bar) == /foo
## dirname(d:\foo\bar.inc) == .
## dirname(/) == /
## dirname(.../foo) == ...
## dirname(./foo) == .
## dirname(foobar///) == .
## dirname(c:\foo) == .


my $expected = "dirname(/foo/) == /\ndirname(/foo) == /\ndirname(/foo/bar) == /foo\ndirname(d\:\\foo\\bar.inc) == .\ndirname(/) == /\ndirname(.../foo) == ...\ndirname(./foo) == .\ndirname(foobar///) == .\ndirname(c\:\\foo) == .\n";

my $result = GET_BODY "/php/dirname.php";
ok $result eq $expected;
