use strict;
use warnings FATAL => 'all';

use constant POST_HUGE => $ENV{APACHE_TEST_POST_HUGE} || 0;

use vars '$client_module';

BEGIN {
    eval {
        #if Inline.pm and libcurl are available
        #we can make this test about 3x faster,
        #after the inlined code is compiled that is.
        require Inline;
        Inline->import(C => 'DATA', LIBS => ['-lcurl'],
                       #CLEAN_AFTER_BUILD => 0,
                       PREFIX => 'http11_post_');
        *request_init = \&curl_init;
        *request_do   = \&curl_do;
        $client_module = 'Inline';
    } if POST_HUGE;

    unless ($client_module) {
        #fallback to lwp
        *request_init = \&lwp_init;
        *request_do   = \&lwp_do;
        $client_module = 'LWP';
    }
}

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#test some sizes too large for mod_echo_post
#and keep the connection alive for kicks

#1k..9k, 10k..50k, 100k, 300k, 500k, 2Mb
my @sizes = (1..9, 10..50, 100, 300, 500, 2000);

#these are too slow to be on by default
#4Mb, 6Mb, 10Mb, 50Mb, 100Mb
my @huge_sizes = (4000, 6000, 10_000, 50_000, 100_000);

push @sizes, @huge_sizes if POST_HUGE;

plan tests => scalar @sizes, [qw(eat_post), $client_module];

my $location = Apache::TestRequest::resolve_url("/eat_post");

request_init($location);

for my $size (@sizes) {
    sok {
        my $length = ($size * 1024);

        my $str = request_do($length);
        chomp $str;

        t_cmp($length, $str, "length posted");
    };
}

sub lwp_init {
    use vars '$UA';
    $UA = Apache::TestRequest::user_agent(keep_alive => 1);
}

sub lwp_do {
    my $length = shift;
    my $remain = $length;

    use constant BUF_SIZE => 8192;

    my $content = sub {
        my $bytes = $remain < BUF_SIZE ? $remain : BUF_SIZE;
        my $buf = 'a' x $bytes;
        $remain -= $bytes;
        $buf;
    };

    my $request = HTTP::Request->new(POST => $location);
    $request->header('Content-length' => $length);
    $request->content($content);

    my $response = $UA->request($request);

    #t_debug $request->headers_as_string;
    #t_debug $response->headers_as_string;

    return $response->content;
}

__DATA__

__C__

#include <curl/curl.h>
#include <curl/easy.h>

static CURL *curl = NULL;
static SV *response = Nullsv;
static long total = 0;

static size_t my_curl_read(char *buffer, size_t size,
                           size_t nitems, void *data)
{
    size_t bytes = nitems < total ? nitems : total;
    memset(buffer, 'a', bytes);
    total -= bytes;
    return bytes;
}

static size_t my_curl_write(char *buffer, size_t size,
                            size_t nitems, void *data)
{
    sv_catpvn(response, buffer, nitems);
    return nitems;
}

void http11_post_curl_init(char *url)
{
    curl = curl_easy_init();
    curl_easy_setopt(curl, CURLOPT_MUTE, 1);
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "POST");
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, my_curl_read);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, my_curl_write);
    response = newSV(0);
}

SV *http11_post_curl_do(long len)
{
    sv_setpv(response, "");
    total = len;
    curl_easy_setopt(curl, CURLOPT_INFILESIZE, len);
    curl_easy_perform(curl);
    return SvREFCNT_inc(response);
}

void http11_post_END(void)
{
    if (response) {
        SvREFCNT_dec(response);
    }
    if (curl) {
        curl_easy_cleanup(curl);
    }
}
