#testing that the server can respond right after client connects,
#before client sends any request data

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $tests = 5;
my $vars = Apache::Test::vars();
my @modules = qw(mod_nntp_like);

if (Apache::Test::have_ssl()) {
    $tests *= 2;
    unshift @modules, 'mod_nntp_like_ssl';
}

plan tests => $tests, ['mod_nntp_like'];

for my $module (@modules) {
    print "testing $module\n";

    my $sock = Apache::TestRequest::vhost_socket($module);
    ok $sock;

    Apache::TestRequest::socket_trace($sock);

    my $response = Apache::TestRequest::getline($sock);

    $response =~ s/[\r\n]+$//;
    ok t_cmp('200 localhost - ready', $response,
             'welcome response');

    for my $data ('LIST', 'GROUP dev.httpd.apache.org', 'ARTICLE 401') {
        $sock->print("$data\n");

        chomp($response = Apache::TestRequest::getline($sock));
        ok t_cmp($data, $response, 'echo');
    }
}
