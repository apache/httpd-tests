use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Time::localtime;

my $config = Apache::Test::config();
my $vars   = Apache::Test::vars();
my $server = $config->server;
my $time = localtime();

(my $mmn = $config->{httpd_info}->{MODULE_MAGIC_NUMBER}) =~ s/:\d+$//;

#Apache::TestRequest::scheme('https');
local $vars->{scheme} = 'https';

my $url = '/test_ssl_var_lookup';
my(%lookup, @vars);

my %client_dn = (
    C  => 'US',
    ST => 'California',
    L  => 'San Francisco',
    O  => 'ASF',
    OU => 'httpd-test',
    CN => 'client_ok',
);

my $client_dn = dn_string(\%client_dn);

my %client_i_dn = %client_dn;
$client_i_dn{CN} = 'localhost';
my $client_i_dn = dn_string(\%client_i_dn);

my %server_dn = (
    C  => 'US',
    ST => 'California',
    L  => 'San Francisco',
    O  => 'httpd-test',
    CN => 'localhost',
);

my $server_dn = dn_string(\%server_dn);

my %server_i_dn = %server_dn;
my $server_i_dn = dn_string(\%server_i_dn);

while (<DATA>) {
    chomp;
    s/^\s+//; s/\s+$//;
    s/\#.*//;
    next unless $_;
    my($key, $val) = split /\s+/, $_, 2;
    next unless $key and $val;

    if ($val =~ /^\"/) {
        $val = eval qq($val);
    }
    elsif ($val =~ /^\'([^\']+)\'$/) {
        $val = $1;
    }
    else {
        $val = eval $val;
    }

    die $@ if $@;

    $lookup{$key} = $val;
    push @vars, $key;
}

plan tests => scalar @vars;

for my $key (@vars) {
    sok { verify($key); };
}

sub verify {
    my $key = shift;
    my @headers;
    if ($key eq 'HTTP_REFERER') {
        push @headers, Referer => $0;
    }
    my $str = GET_BODY("$url?$key", cert => 'client_ok',
                       @headers);
    t_cmp($lookup{$key}, $str, "$key");
}

sub dn_string {
    my($dn) = @_;
    my $string = "";

    for my $k (qw(C ST L O OU CN)) {
        next unless $dn->{$k};
        $string .= "/$k=$dn->{$k}";
    }

    $string;
}

__END__
#http://www.modssl.org/docs/2.8/ssl_reference.html#ToC23
HTTP_USER_AGENT             "libwww-perl/$LWP::VERSION",
HTTP:User-Agent             "libwww-perl/$LWP::VERSION",
HTTP_REFERER                "$0"
HTTP_COOKIE
HTTP_FORWARDED
HTTP_HOST                    Apache::TestRequest::hostport()
HTTP_PROXY_CONNECTION
HTTP_ACCEPT

#standard CGI variables
PATH_INFO
AUTH_TYPE
QUERY_STRING                'QUERY_STRING'
SERVER_SOFTWARE             qr(^$server->{version})
SERVER_ADMIN                $vars->{serveradmin}
SERVER_PORT
SERVER_NAME                 $vars->{servername}
SERVER_PROTOCOL             qr(^HTTP/1\.\d$)
REMOTE_IDENT
REMOTE_ADDR                 $vars->{remote_addr}
REMOTE_HOST
REMOTE_USER
DOCUMENT_ROOT               $vars->{documentroot}
REQUEST_METHOD              'GET'
REQUEST_URI                 $url

#mod_ssl specific variables
TIME_YEAR                    $time->year()+1900
TIME_MON                     $time->mon()+1
TIME_DAY                     $time->mday()
TIME_WDAY                    $time->wday()
TIME
TIME_HOUR
TIME_MIN
TIME_SEC

IS_SUBREQ                    'false'
API_VERSION                  "$mmn"
THE_REQUEST                  qr(^GET $url\?THE_REQUEST HTTP/1\.\d$)
REQUEST_SCHEME               $vars->{scheme}
REQUEST_FILENAME
HTTPS                        'on'
ENV:THE_ARGS                 'ENV:THE_ARGS'

#XXX: should use Net::SSLeay to parse the certs
#rather than hardcode this data
#as the test certs could change in the future
SSL_CLIENT_M_VERSION         '3'
SSL_SERVER_M_VERSION         '3'
SSL_CLIENT_M_SERIAL          '02'
SSL_SERVER_M_SERIAL          '01'
SSL_PROTOCOL                 'TLSv1'
SSL_CLIENT_V_START           'Aug 13 02:05:09 2001 GMT'
SSL_SERVER_V_START           'Aug 11 20:52:30 2001 GMT'
SSL_SESSION_ID
SSL_CLIENT_V_END             'Aug 13 02:05:09 2002 GMT'
SSL_SERVER_V_END             'Aug 11 20:52:30 2002 GMT'
SSL_CIPHER                   'EDH-RSA-DES-CBC3-SHA'
SSL_CIPHER_EXPORT            'false'
SSL_CIPHER_ALGKEYSIZE        '168'
SSL_CIPHER_USEKEYSIZE        '168'

SSL_CLIENT_S_DN              "$client_dn"
SSL_SERVER_S_DN              "$server_dn"
SSL_CLIENT_S_DN_C            "$client_dn{C}"
SSL_SERVER_S_DN_C            "$server_dn{C}"
SSL_CLIENT_S_DN_ST           "$client_dn{ST}"
SSL_SERVER_S_DN_ST           "$server_dn{ST}"
SSL_CLIENT_S_DN_L            "$client_dn{L}"
SSL_SERVER_S_DN_L            "$server_dn{L}"
SSL_CLIENT_S_DN_O            "$client_dn{O}"
SSL_SERVER_S_DN_O            "$server_dn{O}"
SSL_CLIENT_S_DN_OU           "$client_dn{OU}"
SSL_SERVER_S_DN_OU
SSL_CLIENT_S_DN_CN           "$client_dn{CN}"
SSL_SERVER_S_DN_CN           "$server_dn{CN}"
SSL_CLIENT_S_DN_T
SSL_SERVER_S_DN_T
SSL_CLIENT_S_DN_I
SSL_SERVER_S_DN_I
SSL_CLIENT_S_DN_G
SSL_SERVER_S_DN_G
SSL_CLIENT_S_DN_S
SSL_SERVER_S_DN_S
SSL_CLIENT_S_DN_D
SSL_SERVER_S_DN_D
SSL_CLIENT_S_DN_UID
SSL_SERVER_S_DN_UID
SSL_CLIENT_S_DN_Email
SSL_SERVER_S_DN_Email

SSL_CLIENT_I_DN              "$client_i_dn"
SSL_SERVER_I_DN              "$server_i_dn"
SSL_CLIENT_I_DN_C            "$client_i_dn{C}"
SSL_SERVER_I_DN_C            "$server_i_dn{C}"
SSL_CLIENT_I_DN_ST           "$client_i_dn{ST}"
SSL_SERVER_I_DN_ST           "$server_i_dn{ST}"
SSL_CLIENT_I_DN_L            "$client_i_dn{L}"
SSL_SERVER_I_DN_L            "$server_i_dn{L}"
SSL_CLIENT_I_DN_O            "$client_i_dn{O}"
SSL_SERVER_I_DN_O            "$server_i_dn{O}"
SSL_CLIENT_I_DN_OU           "$client_i_dn{OU}"
SSL_SERVER_I_DN_OU
SSL_CLIENT_I_DN_CN           "$client_i_dn{CN}"
SSL_SERVER_I_DN_CN           "$server_i_dn{CN}"
SSL_CLIENT_I_DN_T
SSL_SERVER_I_DN_T
SSL_CLIENT_I_DN_I
SSL_SERVER_I_DN_I
SSL_CLIENT_I_DN_G
SSL_SERVER_I_DN_G
SSL_CLIENT_I_DN_S
SSL_SERVER_I_DN_S
SSL_CLIENT_I_DN_D
SSL_SERVER_I_DN_D
SSL_CLIENT_I_DN_UID
SSL_SERVER_I_DN_UID
SSL_CLIENT_I_DN_Email
SSL_SERVER_I_DN_Email
SSL_CLIENT_A_SIG             'md5WithRSAEncryption'
SSL_SERVER_A_SIG             'md5WithRSAEncryption'
SSL_CLIENT_A_KEY             'rsaEncryption'
SSL_SERVER_A_KEY             'rsaEncryption'
SSL_CLIENT_CERT              qr(^-----BEGIN CERTIFICATE-----)
SSL_SERVER_CERT              qr(^-----BEGIN CERTIFICATE-----)
#SSL_CLIENT_CERT_CHAINn
SSL_CLIENT_VERIFY            'SUCCESS'
SSL_VERSION_LIBRARY
SSL_VERSION_INTERFACE

