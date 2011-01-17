use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#
# test <If > section merging
#

plan tests => 11*2,
                  need need_lwp,
                  need_module('mod_headers'),
                  need_min_apache_version('2.3.8');


sub do_test
{
    my $url = shift;
    my $set = shift;
    my $expect = shift;

    $url = "/if_sec$url";

    my @headers_to_set = split(/\s+/, $set);
    my @headers = map { ("In-If$_" => 1) } @headers_to_set;

    my $response = GET($url, @headers);
    print "# $url with '$set':\n";
    ok t_cmp($response->code, 200);
    ok t_cmp($response->header("Out-Trace"), $expect);
}

do_test('/',                '',    undef); 
do_test('/foo.if_test',     '',    undef); 
do_test('/foo.if_test',     '1',   'global1'); 
do_test('/foo.if_test',     '1 2', 'global1, files2'); 
do_test('/dir/foo.txt',     '1 2', 'global1, dir1, dir2, dir_files1'); 
do_test('/dir/',            '1 2', 'global1, dir1, dir2'); 
do_test('/loc/',            '1 2', 'global1, loc1, loc2'); 
do_test('/loc/foo.txt',     '1 2', 'global1, loc1, loc2'); 
do_test('/loc/foo.if_test', '1 2', 'global1, files2, loc1, loc2'); 
do_test('/proxy/',          '1 2', 'global1, locp1, locp2'); 
do_test('/proxy/',          '2',   'locp2'); 

