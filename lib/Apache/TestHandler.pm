package Apache::TestHandler;

use Apache::Test ();

#some utility handlers for testing hooks other than response
#see modperl-2.0/t/hooks/TestHooks/authen.pm

#compat with 1.xx
my $send_http_header = Apache->can('send_http_header') || sub {};
my $print = Apache->can('print') || Apache::RequestRec->can('puts');

sub ok {
    my $r = shift;
    $r->$send_http_header;
    $r->content_type('text/plain');
    $r->$print("ok");
    0;
}

sub ok1 {
    my $r = shift;
    Apache::Test::plan($r, tests => 1);
    Apache::Test::ok(1);
    0;
}

1;
