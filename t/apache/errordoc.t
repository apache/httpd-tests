use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

Apache::TestRequest::module('error_document');

plan tests => 14, have_lwp;

# basic ErrorDocument tests

{
    my $response = GET '/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             'notfound.html code');

    ok t_cmp($content,
             qr'per-server 404',
             'notfound.html content');
}

{
    my $response = GET '/inherit/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/inherit/notfound.html code');

    ok t_cmp($content,
             qr'per-server 404',
             '/inherit/notfound.html content');
}

{
    my $response = GET '/redefine/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/redefine/notfound.html code');

    ok t_cmp('per-dir 404',
             $content,
             '/redefine/notfound.html content');
}

{
    my $response = GET '/restore/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/redefine/notfound.html code');

    # 1.3 requires quotes for hard-coded messages
    my $expected = have_min_apache_version('2.1') ? qr/Not Found/ : 
                   have_apache(2)                 ? 'default'     :
                   qr/Additionally, a 500/;

    ok t_cmp($content,
             $expected,
             '/redefine/notfound.html content');
}

{
    my $response = GET '/apache/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/merge/notfound.html code');

    ok t_cmp('testing merge',
             $content,
             '/merge/notfound.html content');
}

{
    my $response = GET '/apache/etag/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/merge/merge2/notfound.html code');

    ok t_cmp('testing merge',
             $content,
             '/merge/merge2/notfound.html content');
}

{
    my $response = GET '/bounce/notfound.html';
    chomp(my $content = $response->content);

    ok t_cmp(404,
             $response->code,
             '/bounce/notfound.html code');

    ok t_cmp($content,
             qr!expire test!,
             '/bounce/notfound.html content');
}
