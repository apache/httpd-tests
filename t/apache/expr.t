use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_write_file);
use File::Spec;

# test ap_expr

Apache::TestRequest::user_agent(keep_alive => 1);

my @test_cases = (
    [ 'true'  => 1     ],
    [ 'false' => 0     ],
    [ 'foo'   => undef ],
    # integer comparison
    [ '1 -eq 01' => 1 ],
    [ '1 -eq  2' => 0 ],
    [ '1 -ne  2' => 1 ],
    [ '1 -ne  1' => 0 ],
    [ '1 -lt 02' => 1 ],
    [ '1 -lt  1' => 0 ],
    [ '1 -le  2' => 1 ],
    [ '1 -le  1' => 1 ],
    [ '2 -gt  1' => 1 ],
    [ '1 -gt  1' => 0 ],
    [ '2 -ge  1' => 1 ],
    [ '1 -ge  1' => 1 ],
    [ '1 -gt -1' => 1 ],
    # string comparison
    [ q{'aa' == 'aa'}  => 1 ],
    [ q{'aa' == 'b'}   => 0 ],
    [ q{'aa' =  'aa'}  => 1 ],
    [ q{'aa' =  'b'}   => 0 ],
    [ q{'aa' != 'b'}   => 1 ],
    [ q{'aa' != 'aa'}  => 0 ],
    [ q{'aa' <  'b'}   => 1 ],
    [ q{'aa' <  'aa'}  => 0 ],
    [ q{'aa' <= 'b'}   => 1 ],
    [ q{'aa' <= 'aa'}  => 1 ],
    [ q{'b'  >  'aa'}  => 1 ],
    [ q{'aa' >  'aa'}  => 0 ],
    [ q{'b'  >= 'aa'}  => 1 ],
    [ q{'aa' >= 'aa'}  => 1 ],
    # string operations/whitespace handling
    [ q{'a' . 'b' . 'c' = 'abc'}              => 1 ],
    [ q{'a' .'b'. 'c' = 'abc'}                => 1 ],
    [ q{ 'a' .'b'. 'c'='abc' }                => 1 ],
    [ q{'a1c' = 'a'. 1. 'c'}                  => 1 ],
    [ q{req('foo') . 'bar' = 'bar'}           => 1 ],
    [ q[%{req:foo} . 'bar' = 'bar']           => 1 ],
    [ q[%{req:foo} . 'bar' = 'bar']           => 1 ],
    [ q[%{req:User-Agent} . 'bar' != 'bar']   => 1 ],
    [ q['%{req:User-Agent}' . 'bar' != 'bar'] => 1 ],
    [ q['%{TIME}' . 'bar' != 'bar']           => 1 ],
    [ q[%{TIME} != '']                        => 1 ],
    # string lists
    [ q{'a' -in { 'b', 'a' } } => 1 ],
    [ q{'a' -in { 'b', 'c' } } => 0 ],
    # variables
    [ q[%{TIME_YEAR} =~ /^\d{4}$/]               => 1 ],
    [ q[%{TIME_YEAR} =~ /^\d{3}$/]               => 0 ],
    [ q[%{TIME_MON}  -gt 0 && %{TIME_MON}  -le 12 ] => 1 ],
    [ q[%{TIME_DAY}  -gt 0 && %{TIME_DAY}  -le 31 ] => 1 ],
    [ q[%{TIME_HOUR} -ge 0 && %{TIME_HOUR} -lt 24 ] => 1 ],
    [ q[%{TIME_MIN}  -ge 0 && %{TIME_MIN}  -lt 60 ] => 1 ],
    [ q[%{TIME_SEC}  -ge 0 && %{TIME_SEC}  -lt 60 ] => 1 ],
    [ q[%{TIME} =~ /^\d{14}$/]                   => 1 ],
    [ q[%{API_VERSION} -gt 20101001 ]            => 1 ],
    [ q[%{REQUEST_METHOD} == 'GET' ]             => 1 ],
    [ q['x%{REQUEST_METHOD}' == 'xGET' ]         => 1 ],
    [ q['x%{REQUEST_METHOD}y' == 'xGETy' ]       => 1 ],
    [ q[%{REQUEST_SCHEME} == 'http' ]            => 1 ],
    [ q[%{REQUEST_URI} == '/apache/expr/index.html' ] => 1 ],
    # request headers
    [ q[%{req:referer}     = 'SomeReferer' ] => 1 ],
    [ q[req('Referer')     = 'SomeReferer' ] => 1 ],
    [ q[http('Referer')    = 'SomeReferer' ] => 1 ],
    [ q[%{HTTP_REFERER}    = 'SomeReferer' ] => 1 ],
    [ q[req('User-Agent')  = 'SomeAgent'   ] => 1 ],
    [ q[%{HTTP_USER_AGENT} = 'SomeAgent'   ] => 1 ],
    [ q[req('SomeHeader')  = 'SomeValue'   ] => 1 ],
    [ q[req('SomeHeader2') = 'SomeValue'   ] => 0 ],
    # functions
    [ q[toupper('abC12d') = 'ABC12D' ] => 1 ],
    [ q[tolower('abC12d') = 'abc12d' ] => 1 ],
    [ q[escape('?')       = '%3f' ]    => 1 ],
    [ q[unescape('%3f')   = '?' ]      => 1 ],
    [ q[toupper(escape('?')) = '%3F' ] => 1 ],
    [ q[tolower(toupper(escape('?'))) = '%3f' ] => 1 ],
    [ q[file('] . Apache::Test::vars('serverroot')
      . q[/htdocs/expr/index.html') = 'foo\n' ]  => 1 ],
    # error handling
    [ q['%{foo:User-Agent}' != 'bar'] => undef ],
    [ q[%{foo:User-Agent} != 'bar']   => undef ],
    [ q[foo('bar') = 'bar']           => undef ],
    [ q[%{FOO} != 'bar']              => undef ],
    [ q['bar' = bar]                  => undef ],
);

plan tests => scalar(@test_cases),
                  need need_lwp,
                  need_module('mod_authz_core'),
                  need_min_apache_version('2.3.9');

foreach my $t (@test_cases) {
    my ($expr, $expect) = @{$t};

    write_htaccess($expr);

    my $response = GET('/apache/expr/index.html',
                       'SomeHeader' => 'SomeValue',
                       'User-Agent' => 'SomeAgent',
                       'Referer'    => 'SomeReferer');
    if (!defined $expect) {
        my $passed = ($response->code == 500);
        print qq{Should get parse error for "$expr"\n};
        ok($passed);
    }
    elsif ($expect) {
        my $passed = ($response->code == 403);
        print qq{"$expr" should evaluate to true\n};
        ok($passed);
    }
    else {
        my $passed = ($response->code == 200);
        print qq{"$expr" should evaluate to false\n};
        ok($passed);
    }
}


sub write_htaccess
{
    my $expr = shift;
    my $file = File::Spec->catfile(Apache::Test::vars('serverroot'), 'htdocs', 'apache', 'expr', '.htaccess');
    t_write_file($file, << "EOF" );
<If "$expr">
    Require all denied
</If>
EOF
}

