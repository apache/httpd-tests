package Apache::TestRequest;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();

my $have_lwp = eval {
    require LWP::UserAgent;
    require HTTP::Request::Common;
};

sub has_lwp { $have_lwp }

unless ($have_lwp) {
    #need to define the shortcuts even though the wont be used
    #so Perl can parse test scripts
    @HTTP::Request::Common::EXPORT = qw(GET HEAD POST PUT);
}

require Exporter;
*import = \&Exporter::import;
our @EXPORT = @HTTP::Request::Common::EXPORT;

our @ISA = qw(LWP::UserAgent);

my $UA;
my $Config;

sub hostport {
    my $config = shift || test_config();
    my $hostport = $config->{hostport};

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
    my $hostport = hostport($Config);
    my $scheme = $Apache::TestRequest::Scheme || 'http';
    return "$scheme://$hostport$url";
}

my %wanted_args = map {$_, 1} qw(username password realm content filename);

sub wanted_args {
    \%wanted_args;
}

sub filter_args {
    my $args = shift;
    my(@pass, %keep);

    my @filter = @$args;

    if (ref($filter[0])) {
        push @pass, shift @filter;
    }

    while (my($key, $val) = splice @filter, 0, 2) {
        if ($wanted_args{$key}) {
            $keep{$key} = $val;
        }
        else {
            push @pass, $key, $val;
        }
    }

    return (\@pass, \%keep);
}

my %credentials;

sub get_basic_credentials {
    my($self, $realm, $uri, $proxy) = @_;

    for ($realm, '__ALL__') {
        next unless $credentials{$_};
        return @{ $credentials{$_} };
    }

    return (undef,undef);
}

sub test_config {
    $Config ||= Apache::TestConfig->thaw;
}

sub vhost_socket {
    local $Apache::TestRequest::Module = shift;
    my $hostport = hostport(test_config());
    require IO::Socket;
    IO::Socket::INET->new($hostport);
}

sub prepare {
    eval { $UA ||= __PACKAGE__->new; };
    $Config ||= test_config();

    my $url = resolve_url(shift);
    my($pass, $keep) = filter_args(\@_);

    %credentials = ();
    if ($keep->{username}) {
        $credentials{$keep->{realm} || '__ALL__'} =
          [$keep->{username}, $keep->{password}];
    }
    if (my $content = $keep->{content}) {
        if ($content eq '-') {
            $content = join '', <STDIN>;
        }
        push @$pass, content => $content;
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

my %shortcuts = (RC   => sub { shift->code },
                 OK   => sub { shift->is_success },
                 STR  => sub { shift->as_string },
                 BODY => sub { shift->content });

for my $name (@EXPORT) {
    my $method = \&{"HTTP::Request::Common::$name"};
    no strict 'refs';

    *$name = sub {
        my($url, $pass, $keep) = prepare(@_);
        return $UA->request($method->($url, @$pass));
    };

    while (my($shortcut, $cv) = each %shortcuts) {
        my $alias = join '_', $name, $shortcut;
        *$alias = sub { (\&{$name})->(@_)->$cv; };
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
        return test_config()->http_raw_get(shift, $name);
    };
}

sub http_raw_get {
    my($config, $url, $want_headers) = @_;

    $url ||= "/";
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

#want news: urls to work with the LWP shortcuts
#but cant find a clean way to override the default nntp port
#by brute force we trick Net::NTTP into calling FixupNNTP::new
#instead of IO::Socket::INET::new, we fixup the args then forward
#to IO::Socket::INET::new

if (eval { require Net::NNTP }) {
    my $new;

    for (@Net::NNTP::ISA) {
        last if $new = $_->can('new');
    }

    unshift @Net::NNTP::ISA, 'FixupNNTP';

    *FixupNNTP::new = sub {
        my $class = shift;
        my $args = {@_};
        my($host, $port) = split ':',
          Apache::TestRequest::hostport();
        $args->{PeerPort} = $port;
        $args->{PeerAddr} = $host;
        return $new->($class, %$args);
    }
}

1;
