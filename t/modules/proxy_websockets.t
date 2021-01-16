use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

use AnyEvent;
use AnyEvent::WebSocket::Client;

my $total_tests = 1;

plan tests => $total_tests, need  'AnyEvent', need_module 'proxy_http', need_module 'lua', need_min_apache_version('2.5.1');
;

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport();

my $client = AnyEvent::WebSocket::Client->new;

my $quit_program = AnyEvent->condvar;

my $pingok = 0;

$client->connect("ws://$hostport/proxy/wsoc")->cb(sub {
  our $connection = eval { shift->recv };
  t_debug("wsoc connected");
  if($@) {
    # handle error...
    warn $@;
    return;
  }

  $connection->send('ping');

  # recieve message from the websocket...
  $connection->on(each_message => sub {
    # $connection is the same connection object
    # $message isa AnyEvent::WebSocket::Message
    my($connection, $message) = @_;
    t_debug("wsoc msg received: " . $message->body);
    if ("ping" eq $message->body) { 
      $pingok = 1;
    }
    $connection->send('quit');
    $quit_program->send();
  });
});

$quit_program->recv;
ok t_cmp($pingok, 1);
