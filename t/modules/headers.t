use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

## 
## mod_headers tests
##

my $htdocs = Apache::Test::vars('documentroot');
my $htaccess = "$htdocs/modules/headers/htaccess/.htaccess";
my @header_types = ('set', 'append', 'add', 'unset');
    
plan tests => 
    @header_types**4 + @header_types**3 + @header_types**2 + @header_types**1,
    have_module 'headers';

foreach my $header1 (@header_types) {

    ok test_header($header1);
    foreach my $header2 (@header_types) {

        ok test_header($header1, $header2);
        foreach my $header3 (@header_types) {

            ok test_header($header1, $header2, $header3);
            foreach my $header4 (@header_types) {

                ok test_header($header1, $header2, $header3, $header4);

            }

        }

    }

}

## clean up ##
unlink $htaccess;

sub test_header {
    my @h = @_;
    my $test_header = "Test-Header";
    my (@expected_value, @actual_value) = ((),());
    my ($expected_exists, $expected_value, $actual_exists) = (0,0,0);

    open (HT, ">$htaccess");
    foreach (@h) {

        ## create a unique header value ##
        my $r = int(rand(9999));
        my $test_value = "mod_headers test header value $r";
        
        ## evaluate $_ to come up with expected results
        ## and write out the .htaccess file
        if ($_ eq 'unset') {
            print HT "Header $_ $test_header\n";
            @expected_value = ();
            $expected_exists = 0;
            $expected_value = 0;
        } else {
            print HT "Header $_ $test_header \"$test_value\"\n";

            if ($_ eq 'set') {

                ## should 'set' work this way?
                ## currently, even if there are multiple headers
                ## with the same name, 'set' blows them all away
                ## and sets a single one with this value.
                @expected_value = ();
                $expected_exists = 1;

                $expected_value = $test_value;
            } elsif ($_ eq 'append') {

                ## should 'append' work this way?
                ## currently, if there are multiple headers
                ## with the same name, 'append' appends the value
                ## to the FIRST instance of that header.
                if (@expected_value) {
                    $expected_value[0] .= ", $test_value";

                } elsif ($expected_value) {
                    $expected_value .= ", $test_value";
                } else {
                    $expected_value = $test_value;
                }
                $expected_exists++ unless $expected_exists;

            } elsif ($_ eq 'add') {
                if ($expected_value) {
                    push(@expected_value, $expected_value);
                    $expected_value = 0;
                }
                $expected_value = $test_value;
                $expected_exists++;
            }
        }
    }
    close(HT);

    push(@expected_value, $expected_value) if $expected_value;

    ## get the actual headers ##
    my $h = HEAD_STR "/modules/headers/htaccess/";

    ## parse response headers looking for our headers
    ## and save the value(s)
    my $exists = 0;
    my $actual_value;
    foreach my $head (split /\n/, $h) {
        if ($head =~ /^$test_header: (.*)$/) {
            $actual_exists++;
            push(@actual_value, $1);
        }
    }

    ## ok if 'unset' and there are no headers ##
    return 1 if ($actual_exists == 0 and $expected_exists == 0);

    if (($actual_exists == $expected_exists) &&
        (@actual_value == @expected_value)) {

        ## go through each actual header ##
        foreach my $av (@actual_value) {
            my $matched = 0;

            ## and each expected header ##
            for (my $i = 0 ; $i <= @expected_value ; $i++) {

                if ($av eq $expected_value[$i]) {

                    ## if we match actual and expected,
                    ## record it, and remove the header
                    ## from the expected list
                    $matched++;
                    splice(@expected_value, $i, 1);
                    last;

                }
            }

            ## not ok if actual value does not match expected ##
            return 0 unless $matched;
        }

        ## if we made it this far, all is well. ##
        return 1;

    } else {

        ## not ok if the number of expected and actual
        ## headers do not match
        return 0;

    }
}
