package Apache::TestCommon;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#this module contains common tests that are called from different .t files

#t/apache/passbrigade.t
#t/apache/rwrite.t

sub run_write_test {
    my $module = shift;

    #1k..9k, 10k..50k, 100k, 300k, 500k, 2Mb, 4Mb, 6Mb, 10Mb
    my @sizes = (1..9, 10..50, 100, 300, 500, 2000, 4000, 6000, 10_000);
    my @buff_sizes = (1024, 8192);

    plan tests => @sizes * @buff_sizes, [$module, 'LWP'];

    my $location = "/$module";
    my $ua = Apache::TestRequest::user_agent();

    for my $buff_size (@buff_sizes) {
        for my $size (@sizes) {
            my $length = $size * 1024;
            my $received = 0;

            $ua->do_request(GET => "$location?$buff_size,$length",
                            sub {
                                my($chunk, $res) = @_;
                                $received += length $chunk;
                            });

            ok t_cmp($length, $received, 'bytes in body');
        }
    }
}

1;
__END__
