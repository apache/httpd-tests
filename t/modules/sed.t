use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my @ts = (
   # see t/conf/extra.conf.in
   { url => "/apache/sed/out-foo/foobar.html", content => 'barbar', msg => "sed output filter", code => '200' },
   # mod_sed gives up with ENOMEM once the substituted line grows past
   # MAX_BUF_SIZE.  Whether a 200 was sent first depends on where the last
   # read lands: if the handler's final write leaves data in the buffer, it
   # is flushed with the EOS, mod_sed fails on that brigade and drops the
   # EOS, and no response is sent at all.  Accept either outcome.
   { url => "/apache/sed-echo/out-foo-grow/foobar.html", content => "", msg => "sed output filter too large",
     code => qr/^(?:200|5\d\d)$/, body=>"foo" x (8192*1024), resplen=>0},
   { url => "/apache/sed-echo/input", content => 'barbar', msg => "sed input filter", code => '200', body=>"foobar" },
   { url => "/apache/sed-echo/input", content => undef, msg => "sed input filter", code => '200', body=>"foo" x (1024)},
   # fixme: returns 400 default error doc for some people instead
   # { url => "/apache/sed-echo/input", content => '!!!ERROR!!!', msg => "sed input filter", code => '200', skippable=>true body=>"foo" x (1024*4096)}
);

my $tests = 2*scalar @ts;

plan tests => $tests, need 'LWP::Protocol::AnyEvent::http', need_module('sed');

# Hack to allow streaming of data in/out of mod_echo
require LWP::Protocol::AnyEvent::http;

for my $t (@ts) {
  my $req;
  if (defined($t->{'body'})) { 
    t_debug "posting body of size  ". length($t->{'body'});
    $req = POST  $t->{'url'}, content => $t->{'body'};
    t_debug "... posted body of size  ". length($t->{'body'});
  }
  else { 
    $req = GET $t->{'url'};
  }
  t_debug "Content Length " . length $req->content;
  ok t_cmp($req->code, $t->{'code'}, "status code for " . $t->{'url'});
  if (defined($t->{content})) { 
    my $content = $req->content;
    chomp($content);
    ok t_cmp($content, $t->{content}, $t->{msg});
  }
  else { 
    ok "no body check";
  }
}


