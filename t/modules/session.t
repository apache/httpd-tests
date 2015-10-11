use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

##
## mod_session tests
##

# Code, session data, dirty, expiry, content.
my $checks_per_test = 5;

# Session, API, Encoding, SessionEnv, SessionHeader, SessionMaxAge,
# SessionInclude/Exclude.
my $num_tests = 2 + 4 + 5 + 2 + 1 + 4 + 3;

my @todo = [
    # Session writable after decode failure - PR 58171
    53, 54,
    # Session writable after expired - PR 56052
    88, 89
];

plan tests => $num_tests * $checks_per_test,
              todo => @todo,
              need need_module('session'),
              need_min_apache_version('2.3.0');

# APR time is in microseconds.
use constant APR_TIME_PER_SEC => 1000000;

# check_result(name, res, session, dirty, expiry, response)
sub check_result
{
    my $name = shift;
    my $res = shift;
    my $session = shift // '(none)';
    my $dirty = shift // 0;
    my $expiry = shift // 0;
    my $response = shift // '';

    ok t_cmp($res->code, 200, "response code ($name)");
    my $gotSession = $res->header('X-Test-Session') // '(none)';
    my $sessionData = $gotSession;

    if ($gotSession =~ /^(?:(.+)&)?expiry=([0-9]+)(?:&(.*))?$/i) {
        my $gotExpiry = $2 / APR_TIME_PER_SEC;
        t_debug "expiry of $gotExpiry ($name)";
        ok $expiry && time() < $gotExpiry;

        # Combine the remaining data (if there is any) without the expiry.
        $sessionData = join('&', grep(defined, ($1, $3)));
    }
    else {
        t_debug "no expiry ($name)";
        ok !$expiry;
    }

    ok t_cmp($sessionData, $session, "session header ($name)");
    my $got = $res->header('X-Test-Session-Dirty') // 0;
    ok t_cmp($got, $dirty, "session dirty ($name)");
    $got = $res->content;
    chomp($got);
    ok t_cmp($got, $response, "body ($name)");
    return $gotSession;
}

# check_get(name, path, session, dirty, expiry, response)
sub check_get
{
    my $name = shift;
    my $path = shift;

    t_debug "$name: GET $path";
    my $res = GET "/sessiontest$path";
    return check_result $name, $res, @_;
}

# check_post(name, path, data, session, dirty, expiry, response)
sub check_post
{
    my $name = shift;
    my $path = shift;
    my $data = shift;

    t_debug "$name: POST $path";
    my $res = POST "/sessiontest$path", content => $data;
    return check_result $name, $res, @_;
}

# check_custom(name, result, session, dirty, expiry, response)
sub check_custom
{
    my $name = shift;
    my $res = shift;

    t_debug "$name";
    return check_result $name, $res, @_;
}

my $session = 'test=value';
my $encoded_prefix = 'TestEncoded:';
my $encoded_session = $encoded_prefix . $session;
my $create_session = 'action=set&name=test&value=value';
my $read_session = 'action=get&name=test';

# Session directive
check_get 'Session Off', '/';
check_get 'Session On', '/on', '';

# API optional functions
check_post 'Set session', '/on', $create_session, $session, 1;
check_post 'Get session', "/on?$session", $read_session,
    $session, 0, 0, 'value';
check_post 'Delete session', "/on?$session", 'action=set&name=test', '', 1;
check_post 'Edit session', "/on?$session", 'action=set&name=test&value=',
    'test=', 1;

# Encoding hooks
check_post 'Encode session', '/on/encode', $create_session,
    $encoded_session, 1;
check_post 'Decode session', "/on/encode?$encoded_session", $read_session,
    $encoded_session, 0, 0, 'value';
check_get 'Custom decoder failure', "/on/encode?$session", $encoded_prefix;
check_get 'Identity decoder failure', "/on?&=test", '';
check_post 'Session writable after decode failure', "/on/encode?$session",
    $create_session, $encoded_session, 1;

# SessionEnv directive - requires mod_include
if (have_module('include')) {
    check_custom 'SessionEnv Off', GET("/modules/session/env.shtml?$session"),
        $session, 0, 0, '(none)';
    check_get 'SessionEnv On', "/on/env/on/env.shtml?$session",
        $session, 0, 0, $session;
}
else {
    for (1 .. 2 * $checks_per_test) {
        skip "SessionEnv tests require mod_include", 1;
    }
}

# SessionHeader directive
check_custom 'SessionHeader', GET("/sessiontest/on?$session&another=1",
                              'X-Test-Session-Override' => 'another=5&last=7'),
    "$session&another=5&last=7", 1;

# SessionMaxAge directive
my $future_expiry = (time() + 100) * APR_TIME_PER_SEC;

check_get 'SessionMaxAge adds expiry', "/on/expire?$session", $session, 0, 1;
check_get 'Discard expired session', "/on/expire?$session&expiry=1", '', 0, 1;
check_get 'Keep non-expired session',
    "/on/expire?$session&expiry=$future_expiry", $session, 0, 1;
check_post 'Session writable after expired', '/on/expire?expiry=1',
    $create_session, $session, 1, 1;

# SessionInclude/Exclude directives
check_get 'Not in SessionInclude', "/on/include?$session";
check_get 'SessionInclude', "/on/include/yes?$session", $session;
check_get 'SessionExclude', "/on/include/yes/no?$session";
