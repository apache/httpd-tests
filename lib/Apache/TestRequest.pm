package Apache::TestRequest;

use strict;
use warnings FATAL => 'all';

BEGIN { $ENV{PERL_LWP_USE_HTTP_10} = 1; } #default to http/1.0

use Apache::Test ();
use Apache::TestConfig ();

use constant TRY_TIMES => 50;
use constant INTERP_KEY => 'X-PerlInterpreter';
use constant UA_TIMEOUT => 60 * 10; #longer timeout for debugging

my $have_lwp = eval {
    require LWP::UserAgent;
    require HTTP::Request::Common;

    unless (defined &HTTP::Request::Common::OPTIONS) {
        package HTTP::Request::Common;
        no strict 'vars';
        *OPTIONS = sub { _simple_req(OPTIONS => @_) };
        push @EXPORT, 'OPTIONS';
    }
};

sub has_lwp { $have_lwp }

unless ($have_lwp) {
    #need to define the shortcuts even though the wont be used
    #so Perl can parse test scripts
    @HTTP::Request::Common::EXPORT = qw(GET HEAD POST PUT OPTIONS);
}

sub install_http11 {
    eval {
        die "no LWP" unless $have_lwp;
        LWP->VERSION(5.60); #minimal version
        require LWP::Protocol::http;
        #LWP::Protocol::http10 is used by default
        LWP::Protocol::implementor('http', 'LWP::Protocol::http');
    };
}

use vars qw(@EXPORT @ISA $RedirectOK $DebugLWP);

require Exporter;
*import = \&Exporter::import;
@EXPORT = @HTTP::Request::Common::EXPORT;

@ISA = qw(LWP::UserAgent);

my $UA;

sub module {
    my $module = shift;
    $Apache::TestRequest::Module = $module if $module;
    $Apache::TestRequest::Module;
}

sub scheme {
    my $scheme = shift;
    $Apache::TestRequest::Scheme = $scheme if $scheme;
    $Apache::TestRequest::Scheme;
}

sub user_agent {
    my $args = {@_};

    $args->{keep_alive} ||= $ENV{APACHE_TEST_HTTP11};

    if ($args->{keep_alive}) {
        install_http11();
        eval {
            require LWP::Protocol::https; #https10 is the default
            LWP::Protocol::implementor('https', 'LWP::Protocol::https');
        };
    }

    eval { $UA ||= __PACKAGE__->new(@_); };
}

sub hostport {
    my $config = shift || Apache::Test::config();
    local $config->{vars}->{scheme} =
      $Apache::TestRequest::Scheme || $config->{vars}->{scheme};
    my $hostport = $config->hostport;

    if (my $module = $Apache::TestRequest::Module) {
        $hostport = $config->{vhosts}->{$module}->{hostport}
          unless $module eq 'default';
    }

    $hostport;
}

sub resolve_url {
    my $url = shift;
    return $url if $url =~ m,^(\w+):/,;
    $url = "/$url" unless $url =~ m,^/,;

    my $vars = Apache::Test::vars();

    local $vars->{scheme} =
      $Apache::TestRequest::Scheme || $vars->{scheme} || 'http';

    my $hostport = hostport();

    return "$vars->{scheme}://$hostport$url";
}

my %wanted_args = map {$_, 1} qw(username password realm content filename
                                 redirect_ok cert);

sub wanted_args {
    \%wanted_args;
}

$RedirectOK = 1;

sub redirect_ok {
    my($self, $request) = @_;
    return 0 if $request->method eq 'POST';
    $RedirectOK;
}

my %credentials;

#subclass LWP::UserAgent
sub new {
    my $self = shift->SUPER::new(@_);

    lwp_debug(); #init from %ENV (set by Apache::TestRun)

    my $config = Apache::Test::config();
    if (my $proxy = $config->configure_proxy) {
        #t/TEST -proxy
        $self->proxy(http => "http://$proxy");
    }

    $self->timeout(UA_TIMEOUT);

    $self;
}

sub get_basic_credentials {
    my($self, $realm, $uri, $proxy) = @_;

    for ($realm, '__ALL__') {
        next unless $credentials{$_};
        return @{ $credentials{$_} };
    }

    return (undef,undef);
}

sub vhost_socket {
    my $module = shift;
    local $Apache::TestRequest::Module = $module;

    my $hostport = hostport(Apache::Test::config());
    my($host, $port) = split ':', $hostport;
    my(%args) = (PeerAddr => $host, PeerPort => $port);

    if ($module =~ /ssl/) {
        require Net::SSL;
        local $ENV{https_proxy} ||= ""; #else uninitialized value in Net/SSL.pm
        return Net::SSL->new(%args, Timeout => UA_TIMEOUT);
    }
    else {
        require IO::Socket;
        return IO::Socket::INET->new(%args);
    }
}

#Net::SSL::getline is nothing like IO::Handle::getline
#could care less about performance here, just need a getline()
#that returns the same results with or without ssl
my %getline = (
    'Net::SSL' => sub {
        my $self = shift;
        my $buf = '';
        my $c = '';
        do {
            $self->read($c, 1);
            $buf .= $c;
        } until ($c eq "\n");
        $buf;
    },
);

sub getline {
    my $sock = shift;
    my $class = ref $sock;
    my $method = $getline{$class} || 'getline';
    $sock->$method();
}

sub prepare {
    user_agent();

    my $url = resolve_url(shift);
    my($pass, $keep) = Apache::TestConfig::filter_args(\@_, \%wanted_args);

    %credentials = ();
    if (defined $keep->{username}) {
        $credentials{$keep->{realm} || '__ALL__'} =
          [$keep->{username}, $keep->{password}];
    }
    if (my $content = $keep->{content}) {
        if ($content eq '-') {
            $content = join '', <STDIN>;
        }
        elsif ($content =~ /^x(\d+)$/) {
            $content = 'a' x $1;
        }
        push @$pass, content => $content;
    }
    if (exists $keep->{redirect_ok}) {
        $RedirectOK = $keep->{redirect_ok};
    }
    if ($keep->{cert}) {
        set_client_cert($keep->{cert});
    }

    return ($url, $pass, $keep);
}

sub UPLOAD {
    my($url, $pass, $keep) = prepare(@_);

    if ($keep->{filename}) {
        return upload_file($url, $keep->{filename}, $pass);
    }
    else {
        return upload_string($url, $keep->{content});
    }
}

sub UPLOAD_BODY {
    UPLOAD(@_)->content;
}

#lwp only supports files
sub upload_string {
    my($url, $data) = @_;

    my $CRLF = "\015\012";
    my $bound = 742617000027;
    my $req = HTTP::Request->new(POST => $url);

    my $content = join $CRLF,
      "--$bound",
      "Content-Disposition: form-data; name=\"HTTPUPLOAD\"; filename=\"b\"",
      "Content-Type: text/plain", "",
      $data, "--$bound--", "";

    $req->header("Content-Length", length($content));
    $req->content_type("multipart/form-data; boundary=$bound");
    $req->content($content);

    $UA->request($req);
}

sub upload_file {
    my($url, $file, $args) = @_;

    my $content = [@$args, filename => [$file]];

    $UA->request(HTTP::Request::Common::POST($url,
                 Content_Type => 'form-data',
                 Content      => $content,
    ));
}

#useful for POST_HEAD and $DebugLWP (see below)
sub lwp_as_string {
    my($r, $want_body) = @_;
    my $content = $r->content;

    unless ($r->header('Content-length') or $r->header('Transfer-Encoding')) {
        $r->header('Content-length' => length $content);
        $r->header('X-Content-length-note' => 'added by Apache::TestReqest');
    }

    if ($want_body) {
        if (defined $content) {
            #prevent double "ok $x" output
            (my $copy = $content) =~ s/^/\#/mg;
            $r->content($copy);
        }
    }
    else {
        $r->content(undef);
    }

    my $string = $r->as_string;
    $r->content($content); #reset
    $string;
}

$DebugLWP = 0; #1 == print METHOD URL and header response for all requests
               #2 == #1 + response body
               #other == passed to LWP::Debug->import

sub lwp_debug {
    package main; #wtf: else package in perldb changes
    my $val = $_[0] || $ENV{APACHE_TEST_DEBUG_LWP};

    return unless $val;

    if ($val =~ /^\d+$/) {
        $Apache::TestRequest::DebugLWP = $val;
        return "\$Apache::TestRequest::DebugLWP = $val\n";
    }
    else {
        my(@args) = @_ ? @_ : split /\s+/, $val;
        require LWP::Debug;
        LWP::Debug->import(@args);
        return "LWP::Debug->import(@args)\n";
    }
}

sub lwp_call {
    my($name, $shortcut) = (shift, shift);

    my $r = (\&{$name})->(@_);

    unless ($shortcut) {
        #GET, HEAD, POST
        $r = $UA->request($r);
        my $proto = $r->protocol;
        if (defined($proto)) {
            if ($proto !~ /^HTTP\/(\d\.\d)$/) {
                die "response had no protocol (is LWP broken or something?)";
            }
            if ($1 ne "1.0" && $1 ne "1.1") {
                die "response had protocol HTTP/$1 (headers not sent?)";
            }
        }
    }

    if ($DebugLWP and not $shortcut) {
        my($url, @rest) = @_;
        $name = (split '::', $name)[-1]; #strip HTTP::Request::Common::
        $url = resolve_url($url);
        print "$name $url:\n", $r->request->headers->as_string, "\n";
        print lwp_as_string($r, $DebugLWP > 1);
    }

    return $shortcut ? $r->$shortcut() : $r;
}

my %shortcuts = (RC   => sub { shift->code },
                 OK   => sub { shift->is_success },
                 STR  => sub { shift->as_string },
                 HEAD => sub { lwp_as_string(shift, 0) },
                 BODY => sub { shift->content });

for my $name (@EXPORT) {
    my $method = "HTTP::Request::Common::$name";
    no strict 'refs';

    *$name = sub {
        my($url, $pass, $keep) = prepare(@_);
        return lwp_call($method, undef, $url, @$pass);
    };

    while (my($shortcut, $cv) = each %shortcuts) {
        my $alias = join '_', $name, $shortcut;
        *$alias = sub { lwp_call($name, $cv, @_) };
    }
}

my @export_std = @EXPORT;
for my $method (@export_std) {
    push @EXPORT, map { join '_', $method, $_ } keys %shortcuts;
}

push @EXPORT, qw(UPLOAD_BODY);

#this is intended to be a fallback if LWP is not installed
#so at least some tests can be run, it is not meant to be robust

for my $name (qw(GET HEAD)) {
    next if defined &$name;
    no strict 'refs';
    *$name = sub {
        return Apache::Test::config()->http_raw_get(shift, $name);
    };
}

sub http_raw_get {
    my($config, $url, $want_headers) = @_;

    $url ||= "/";

    if ($have_lwp) {
        if ($want_headers) {
            return $want_headers == 1 ? GET_STR($url) : HEAD_STR($url);
        }
        else {
            return GET_BODY($url);
        }
    }

    my $hostport = hostport($config);

    require IO::Socket;
    my $s = IO::Socket::INET->new($hostport);

    unless ($s) {
        warn "cannot connect to $hostport $!";
        return undef;
    }

    print $s "GET $url HTTP/1.0\n\n";
    my($response_line, $header_term, $headers);
    $headers = "";

    while (<$s>) {
        $headers .= $_;
	if(m:^(HTTP/\d+\.\d+)[ \t]+(\d+)[ \t]*([^\012]*):i) {
	    $response_line = 1;
	}
	elsif(/^([a-zA-Z0-9_\-]+)\s*:\s*(.*)/) {
	}
	elsif(/^\015?\012$/) {
	    $header_term = 1;
            last;
	}
    }

    unless ($response_line and $header_term) {
        warn "malformed response";
    }
    my @body = <$s>;
    close $s;

    if ($want_headers) {
        if ($want_headers > 1) {
            @body = (); #HEAD
        }
        unshift @body, $headers;
    }

    return wantarray ? @body : join '', @body;
}

sub to_string {
    my $obj = shift;
    ref($obj) ? $obj->as_string : $obj;
}

# request an interpreter instance and use this interpreter id to
# select the same interpreter in requests below
sub same_interp_tie {
    my($url) = @_;

    my $res = GET($url, INTERP_KEY, 'tie');

    my $same_interp = $res->header(INTERP_KEY);

    return $same_interp;
}

# run the request though the selected perl interpreter, by polling
# until we found it
# currently supports only GET, HEAD, PUT, POST subs
sub same_interp_do {
    my($same_interp, $sub, $url, @args) = @_;

    die "must pass an interpreter id to work with"
        unless defined $same_interp and $same_interp;

    push @args, (INTERP_KEY, $same_interp);

    my $res      = '';
    my $times    = 0;
    my $found_same_interp = '';
    do {
        #loop until we get a response from our interpreter instance
        $res = $sub->($url, @args);

        if ($res and $res->code == 200) {
            $found_same_interp = $res->header(INTERP_KEY) || '';
        }

        unless ($found_same_interp eq $same_interp) {
            $found_same_interp = '';
        }

        if ($times++ > TRY_TIMES) { #prevent endless loop
            die "unable to find interp $same_interp\n";
        }
    } until ($found_same_interp);

    return $found_same_interp ? $res : undef;
}


sub set_client_cert {
    my $name = shift;
    my $config = Apache::Test::config();
    my $dir = "$config->{vars}->{t_conf}/ssl";

    if ($name) {
        $ENV{HTTPS_CERT_FILE} = "$dir/certs/$name.crt";
        $ENV{HTTPS_KEY_FILE}  = "$dir/keys/$name.pem";
    }
    else {
        for (qw(CERT KEY)) {
            delete $ENV{"HTTPS_${_}_FILE"};
        }
    }
}

#want news: urls to work with the LWP shortcuts
#but cant find a clean way to override the default nntp port
#by brute force we trick Net::NTTP into calling FixupNNTP::new
#instead of IO::Socket::INET::new, we fixup the args then forward
#to IO::Socket::INET::new

#also want KeepAlive on for Net::HTTP
#XXX libwww-perl 5.53_xx has: LWP::UserAgent->new(keep_alive => 1);

sub install_net_socket_new {
    my($module, $code) = @_;

    return unless Apache::Test::have_module($module);

    no strict 'refs';

    my $new;
    my $isa = \@{"$module\::ISA"};

    for (@$isa) {
        last if $new = $_->can('new');
    }

    my $fixup_class = "Apache::TestRequest::$module";
    unshift @$isa, $fixup_class;

    *{"$fixup_class\::new"} = sub {
        my $class = shift;
        my $args = {@_};
        $code->($args);
        return $new->($class, %$args);
    };
}

eval {
    install_net_socket_new('Net::NNTP' => sub {
        my $args = shift;
        my($host, $port) = split ':',
          Apache::TestRequest::hostport();
        $args->{PeerPort} = $port;
        $args->{PeerAddr} = $host;
    });
};

1;
