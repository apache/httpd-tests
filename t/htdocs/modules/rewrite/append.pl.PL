
# append.pl
#
#  appends its command line argument to each line of stdin
#  used to test a rewritemap prg: with args
#
$|=1;
while (<STDIN>) {
    chomp;
    print "$_$ARGV[0]\n";
}
