use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

my $total_tests = 1;

plan tests => $total_tests, need 'AnyEvent::WebSocket::Client',
    need_module('proxy_http', 'lua'), need_min_apache_version('2.4.47');

require AnyEvent;
require AnyEvent::WebSocket::Client;

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport();

my $client = AnyEvent::WebSocket::Client->new(timeout => 5);

my $quit_program = AnyEvent->condvar;

my $pingok = 0;

$client->connect("ws://$hostport/proxy/wsoc")->cb(sub {
  our $connection = eval { shift->recv };
  t_debug("wsoc connected");
  if($@) {
    # handle error...
    warn $@;
    $quit_program->send();
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
