package TestBasic::Hello;

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Const -compile => qw(OK);

# XXX: adjust the test that it'll work under mp1 as well

sub handler {

  my $r = shift;

  $r->content_type('text/plain');
  $r->print('Hello');

  return Apache::OK;
}

1;
