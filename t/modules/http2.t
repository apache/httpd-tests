use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

my $num_suite = 26;
my $total_tests = 2 * $num_suite;

plan tests => $total_tests, need_module 'http2', need_module 'Protocol::HTTP2::Client', need_min_apache_version('2.4.17');

Apache::TestRequest::module("http2");

my $config = Apache::Test::config();
my $host = $config->{vars}->{servername};
my $port = $config->{vars}->{port};

my $ssl_module = $config->{vars}->{ssl_module_name};
my $shost      = $config->{vhosts}->{$ssl_module}->{servername};
my $sport      = $config->{vhosts}->{$ssl_module}->{port};
my $serverdir  = $config->{vars}->{t_dir};
my $htdocs     =  $serverdir . "/htdocs";

require Protocol::HTTP2::Client;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Net::SSLeay;
use AnyEvent::TLS;

Net::SSLeay::initialize();

my $alpn_available = exists &Net::SSLeay::CTX_set_alpn_protos;

sub connect_and_do {
    my %args = (
        @_
    );
    my $scheme = $args{ctx}->{scheme};
    my $host   = $args{ctx}->{host};
    my $port   = $args{ctx}->{port};
    my $client = $args{ctx}->{client};
    my $w = AnyEvent->condvar;

    tcp_connect $host, $port, sub {
        my ($fh) = @_ or do {
            print "connection failed: $!\n";
            $w->send;
            return;
        };
        
        my $tls;
        my $tls_ctx;
        if ($scheme eq 'https') {
            $tls = "connect";
            eval {
                # ALPN (Net-SSLeay > 1.55, openssl >= 1.0.1)
                if ( $alpn_available ) {
                    $tls_ctx = AnyEvent::TLS->new( method => "TLSv1_2", );
                    Net::SSLeay::CTX_set_alpn_protos( $tls_ctx->ctx, ['h2'] );
                }
                else {
                    $tls_ctx = AnyEvent::TLS->new();
                }
            };
            if ($@) {
                print "Some problem with SSL CTX: $@\n";
                $w->send;
                return;
            }
        }
        
        my $handle;
        $handle = AnyEvent::Handle->new(
            fh       => $fh,
            tls      => $tls,
            tls_ctx  => $tls_ctx,
            autocork => 1,
            on_error => sub {
                $_[0]->destroy;
                print "connection error\n";
                $w->send;
            },
            on_eof => sub {
                $handle->destroy;
                $w->send;
            }
        );
        
        # First write preface to peer
        while ( my $frame = $client->next_frame ) {
            $handle->push_write($frame);
        }
        
        $handle->on_read(sub {
            my $handle = shift;
            
            $client->feed( $handle->{rbuf} );
            $handle->{rbuf} = undef;
            
            while ( my $frame = $client->next_frame ) {
                $handle->push_write($frame);
            }
            
            # Terminate connection if all done
            $handle->push_shutdown if $client->shutdown;
        });
    };
    $w->recv;
    
}

sub add_request {
    my ($scheme, $client, $host, $port);
    my %args = (
        method  => 'GET',
        headers => [],
        rc      => 200,
        on_done => sub {
            my %args = ( @_ );
            my $ctx  = $args{ctx};
            my $req  = $args{request};
            my $resp = $args{response};
            my $hr = $resp->{headers};
            my %headers = @$hr;
            ok t_cmp($headers{':status'}, $req->{rc}, 
                "$req->{method} $ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{path}");
        },
        @_
    );
    $client = $args{ctx}->{client};
    $scheme = $args{ctx}->{scheme};
    $host   = $args{ctx}->{host};
    $port   = $args{ctx}->{port};
    
    $client->request(
        ':scheme'    => $scheme,
        ':authority' => $args{authority} || $host . ':' . $port,
        ':path'      => $args{path},
        ':method'    => $args{method},
        headers      => $args{headers},
        on_done      => sub {
            my ($headers, $data) = @_;
            $args{on_done}(
                ctx      => $args{ctx}, 
                request  => \%args,
                response => { headers => \@$headers, data => $data }
            );        
        }
    );
}

sub cmp_content_length {
    my %args = ( @_ );
    my $ctx  = $args{ctx};
    my $req  = $args{request};
    my $resp = $args{response};
    my $hr = $resp->{headers};
    my %headers = @$hr;
    ok t_cmp($headers{':status'}, $req->{rc}, 
    "$req->{method} $ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{path}");
    ok t_cmp(length $resp->{data}, $req->{content_length}, "content-length of $req->{path}");
}

sub cmp_content {
    my %args = ( @_ );
    my $ctx  = $args{ctx};
    my $req  = $args{request};
    my $resp = $args{response};
    my $hr = $resp->{headers};
    my %headers = @$hr;
    ok t_cmp($headers{':status'}, $req->{rc}, 
        "$req->{method} $ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{path}");
    ok t_cmp($resp->{data}, $req->{content}, "content of $req->{path}");
}

sub cmp_file_response {
    my %args = ( @_ );
    my $ctx  = $args{ctx};
    my $req  = $args{request};
    my $resp = $args{response};
    my $hr = $resp->{headers};
    my %headers = @$hr;
    ok t_cmp($headers{':status'}, $req->{rc}, 
    "$req->{method} $ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{path}");
    open(FILE, "<$htdocs$req->{path}") or die "cannot open $req->{path}";
    undef $/;
    my $content = <FILE>;
    close(FILE);
    ok t_is_equal($resp->{data}, $content);
}

sub check_redir {
    my %args = ( @_ );
    my $ctx  = $args{ctx};
    my $req  = $args{request};
    my $resp = $args{response};
    my $hr = $resp->{headers};
    my %headers = @$hr;
    ok t_cmp($headers{':status'}, 302, 
        "$req->{method} $ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{path}");
    ok t_cmp(
        $headers{location}, 
        "$ctx->{scheme}://$ctx->{host}:$ctx->{port}$req->{redir_path}", 
        "location header check"
    );
}

sub do_suite {
    my %args = (
        scheme => 'http',
        host   => 'localhost',
        port   => 80,
        @_
    );
    my $true_tls = ($args{scheme} eq 'https' and $alpn_available);
    
    $args{client} = Protocol::HTTP2::Client->new( upgrade => 0 );
    
    print "connect to $args{scheme}:$args{host}:$args{port}\n";
    
    add_request( 
        ctx => \%args, 
        path => '/' 
    );
    add_request( 
        ctx => \%args, 
        rc => 404, 
        path => '/not_here' 
    );
    add_request( 
        ctx    => \%args, 
        rc     => $true_tls? 421 : 404, 
        path   => '/misdirected', 
        header => [ 'host' => 'xxx.yyy.zzz' ] 
    );
    add_request( 
        ctx    => \%args, 
        rc     => $true_tls? 421 : 404, 
        path   => '/misdirected', 
        authority => 'xxx.yyy.zzz:1234'
    );
    add_request( 
        ctx => \%args, 
        path => '/modules/h2/index.html',
        on_done => \&cmp_file_response
    );
    add_request( 
        ctx => \%args, 
        path => '/modules/h2/003/003_img.jpg',
        on_done => \&cmp_file_response
    );
    if (have_module 'mod_rewrite') {
        add_request( 
        ctx  => \%args, 
        path => '/modules/h2/latest.tar.gz',
        redir_path => "/modules/h2/xxx-1.0.2a.tar.gz",
        on_done => \&check_redir
        );
    }
    else {
        skip "skipping test as mod_rewrite not available" foreach(1..2);
    }
    if (have_cgi) {
        my $sni_host = $true_tls? 'localhost' : '';
        my $content = <<EOF;
<html><body>
<h2>Hello World!</h2>
TLS_SNI="$sni_host"
</body></html>
EOF
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/hello.pl',
            content => $content,
            on_done => \&cmp_content,
        );
        
        $content = <<EOF;
<html><body>
<p>No query was specified.</p>
</body></html>
EOF
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl',
            content => $content,
            rc      => 400,
            on_done => \&cmp_content,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=2&text=0123456789',
            content => "01234567890123456789",
            on_done => \&cmp_content,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=10&text=0123456789',
            content_length => 100,
            on_done => \&cmp_content_length,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=100&text=0123456789',
            content_length => 1000,
            on_done => \&cmp_content_length,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=1000&text=0123456789',
            content_length => 10000,
            on_done => \&cmp_content_length,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=10000&text=0123456789',
            content_length => 100000,
            on_done => \&cmp_content_length,
        );
        add_request( 
            ctx     => \%args, 
            path    => '/modules/h2/necho.pl?count=100000&text=0123456789',
            content_length => 1000000,
            on_done => \&cmp_content_length,
        );
    }
    else {
        skip "skipping test as mod_cgi not available" foreach(1..1);
    }
 
    connect_and_do( ctx => \%args );
}

do_suite( 'scheme' => 'http', 'host' => $host, 'port' => $port );


if ($alpn_available||1) {
    do_suite( 'scheme' => 'https', 'host' => $shost, 'port' => $sport );
}
else {
    skip "skipping https tests as ALPN is not available" foreach(1..$num_suite);
}

