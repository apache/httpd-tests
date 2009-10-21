use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

##
## mod_info quick test
##

plan tests => 1, need_module 'info';

my $uri = '/server-info';
my $info = GET_BODY $uri;
my $config = Apache::Test::config();
my $mods = $config->{modules};
my (@actual,@expected) = ((),());

## extract module names from html ##
foreach (split /\n/, $info) {
    if ($_ =~ /<a name=\"(\w+\.c)\">/) {
        if ($1 eq 'util_ldap.c') {
            push(@actual,'mod_ldap.c');
        } else {
            push(@actual, $1);
        }
    }
}

foreach (sort keys %$mods) {
    push(@expected,$_) if $mods->{$_} && !$config->should_skip_module($_);
}
@actual = sort @actual;
@expected = sort @expected;

## verify all mods are there ##
my $ok = 1;
if (@actual == @expected) {
    for (my $i=1 ; $i<@expected ; $i++) {
        if ($expected[$i] ne $actual[$i]) {
            $ok = 0;
            print "comparing expected ->$expected[$i]<-\n";
            print "to actual ->$actual[$i]<-\n";
            print "actual:\n@actual\nexpect:\n@expected\n";
            last;
        }
    }
} else {
    $ok = 0;
    my $a = @actual; my $e = @expected;
    print "actual($a modules):\n@actual\nexpect($e modules):\n@expected\n";
}

ok $ok;
