# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache::TestConfigPHP;

#things specific to php

use strict;
use warnings FATAL => 'all';
use File::Spec::Functions qw(catfile splitdir abs2rel);
use File::Find qw(finddepth);
use Apache::TestTrace;
use Apache::TestRequest;
use Apache::TestConfig;
use Apache::TestConfigPerl;
use Config;

@Apache::TestConfigPHP::ISA = qw(Apache::TestConfig);

sub new {
    return shift->SUPER::new(@_);
}

my %outside_container = map { $_, 1 } qw{
Alias AliasMatch
};

my %strip_tags = map { $_ => 1} qw(base noautoconfig);

#test .php's can have configuration after the __DATA__ token
sub add_module_config {
    # this is just a stub at the moment until somebody gives me
    # an end-of-file PHP token that is similar to __DATA__ or __END__
}

my @extra_subdirs = qw(Response);

sub configure_php_tests_pick {
    my($self, $entries) = @_;

    for my $subdir (@extra_subdirs) {
        my $dir = catfile $self->{vars}->{t_dir}, lc $subdir;
        next unless -d $dir;

        finddepth(sub {
            return unless /\.php$/;

            my $file = catfile $File::Find::dir, $_;
            my $module = abs2rel $file, $dir;
            my $status = $self->run_apache_test_config_scan($file);
            push @$entries, [$file, $module, $subdir, $status];
        }, $dir);
    }
}

sub write_php_test {
    my($self, $location, $test) = @_;

    (my $path = $location) =~ s/test//i;
    (my $file = $test) =~ s/php$/t/i;

    my $dir = catfile $self->{vars}->{t_dir}, lc $path;
    my $t = catfile $dir, $file;
    return if -e $t;

    unless (-e $t) {
        $self->gendir($dir);
        my $fh = $self->genfile($t);

        print $fh <<EOF;
use Apache::TestRequest 'GET_BODY_ASSERT';
print GET_BODY_ASSERT "/$location/$test";
EOF

        close $fh or die "close $t: $!";
    }

    # write out an all.t file for the directory
    # that will skip running all PHP test unless have_php

    my $all = catfile $dir, 'all.t';

    unless (-e $all) {
        my $fh = $self->genfile($all);

        print $fh <<EOF;
use strict;
use warnings FATAL => 'all';

use Apache::Test;

# skip all tests in this directory unless a php module is enabled
plan tests => 1, need_php;

ok 1;
EOF
    }
}

sub configure_php_inc {
    my $self = shift;

    my $serverroot = $self->{vars}->{serverroot};

    my $path = catfile $serverroot, 'conf';

    my $cfg = "php_value include_path $path\n";

    my $php = $self->{vars}->{php_module};

    $self->postamble(IfModule => $php, $cfg);
}

sub configure_php_functions {
    my $self = shift;

    my $dir  = catfile $self->{vars}->{serverroot}, 'conf';
    my $file = catfile $dir, 'more.php';

    $self->gendir($dir);
    my $fh = $self->genfile($file, undef, 1);

    while (my $line = <DATA>) {
      print $fh $line;
    }

    close $fh or die "close $file: $!";

    $self->clean_add_file($file);
}

sub configure_php_tests {
    my $self = shift;

    my @entries = ();
    $self->configure_php_tests_pick(\@entries);
    $self->configure_pm_tests_sort(\@entries);

    my %seen = ();

    for my $entry (@entries) {
        my ($file, $module, $subdir, $status) = @$entry;

        my @args = ();

        my $directives = $self->add_module_config($file, \@args);

        my @parts    = splitdir $file;
        my $test     = pop @parts;
        my $location = $parts[-1];

        debug "configuring PHP test file $file";

        if ($directives->{noautoconfig}) {
            $self->postamble(""); # which adds "\n"
        }
        else {
            unless ($seen{$location}++) {
                $self->postamble(Alias => [ catfile('', $parts[-1]), catfile(@parts) ]);

                my @args = (AddType => 'application/x-httpd-php .php');

                $self->postamble(Location => "/$location", \@args);
            }
        }

        $self->write_php_test($location, $test);
    }
}

1;

__DATA__
<?php

# more.php based on work from Andy Lester.  see
# http://use.perl.org/~petdance/journal/14227

$_test_ntests = 0;
$_nfailures = 0;
$_no_plan = 0;

register_shutdown_function( 'test_end' );

function ok( $condition, $name = '' ) {
    global $_test_ntests;
    global $_nfailures;
    $current_failures = 0;
    ++$_test_ntests;

    $caller = debug_backtrace();
    if (preg_match('/more.php$/', $caller[0]['file'])) {
        $file  = $caller[1]['file'];
        $line  = $caller[1]['line'];
    }
    else {
        $file  = $caller[0]['file'];
        $line  = $caller[0]['line'];
    }

    if ( !$condition ) {
        print "not ";
        ++$_nfailures;
        ++$current_failures;
    }
    print "ok $_test_ntests";

    if ( $name != "" ) {
        print " - $name";
    }
    print "\n";

    if ($current_failures) {
        print "#     Failed test ($file at line $line)\n";
    }

    return $condition;
}

function pass( $name = '' ) {
    return ok( TRUE, $name );
}

function fail( $name = '' ) {
    return ok( FALSE, $name );
}

function skip( $msg, $num ) {
    for ( $i=0; $i<$num; $i++ ) {
        pass( "# SKIP $msg" );
    }
}

function is( $actual, $expected, $name = '' ) {
    $ok = ($expected == $actual);
    ok( $ok, $name );
    if ( !$ok ) {
        diag( "          got: '$actual'" );
        diag( "     expected: '$expected'" );
    }
    return $ok;
}

function isnt( $actual, $dontwant, $name = '' ) {
    $ok = ($actual != $dontwant);
    ok( $ok, $name );
    if ( !$ok ) {
        diag( "Didn't want \"$actual\"" );
    }
    return $ok;
}

function isa_ok( $object, $class, $name = null ) {
    if ( isset( $object ) ) {
        $actual = get_class( $object );
        if ( !isset( $name ) ) {
            $name = "Object is of type $class";
        }
        return is( get_class( $object ), strtolower( $class ), $name );
    } else {
        return fail( "object is undefined" );
    }
}

function like( $string, $regex, $name='' ) {
    return ok( preg_match( $regex, $string ), $name );
}

function diag( $lines ) {
    if ( is_string( $lines ) ) {
        $lines = split( "\n", $lines );
    }
    foreach ( $lines as $str ) {
        print "# $str\n";
    }
}

function plan( $ntests ) {
    print "1..$ntests\n";
}

function no_plan() {
    global $_no_plan;

    $_no_plan = 1;
}

function test_end() {
    global $_no_plan;
    global $_test_ntests;
    if ( $_no_plan ) {
        print "1..$_test_ntests\n";
    }

    # reset for next run
    global $_test_ntests;
    global $_no_plan;
    global $_nfailures;
    $_test_ntests = 0;
    $_no_plan = 0;

    $ver = phpversion();
    if ( version_compare( $ver, '4.2.2' ) > 0 ) { # >4.2.2?
        $_report_failures = $_nfailures;
        $_nfailures = 0;
        exit( $_report_failures > 254 ? 254 : $_report_failures );
    } else {
        $_nfailures = 0;
        # Don't return anything
    }
}

?>
