use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestConfig;

##
## mod_access test
##

my @localhost = (
	'from all',
	'from localhost',
	'from 127.0.0.1',
	'from 127.0',
	'from 127.0.0.1/255.255.0.0',
	'from 127.0.0.1/16',
	'from somewhere.else.com',
	'from 10.0.0.1'
);
my @order = ('deny,allow', 'allow,deny', 'mutual-failure');
my @allow = @localhost;
my @deny = @localhost;

plan tests => (@order * @allow * @deny * 2) + (@order * @allow);

my $env = Apache::TestConfig->thaw;
my $dir = "$env->{vars}->{t_dir}/htdocs/modules/access/htaccess";

foreach my $order (@order) {
	foreach my $allow (@allow) {
		open (HT, ">$dir/.htaccess");
		print HT "Order $order\nAllow $allow\n";
		close (HT);

		if ($order eq 'deny,allow') {

			## if allowing by default,
			## there is no 'Deny' directive, so everything
			## is allowed.
			ok GET_OK "/modules/access/htaccess/index.html";

		} else {

			## denying by default

			if ($allow =~ /^from 127/
			    || $allow =~ /^from localhost$/
			    || $allow =~ /^from all$/) {

				## if we are explicitly allowed, its ok
				ok GET_OK "/modules/access/htaccess/index.html";

			} else {

				## otherwise, not ok
				ok !GET_OK "/modules/access/htaccess/index.html";
			}
		}
			

		foreach my $deny (@deny) {
			open (HT, ">$dir/.htaccess");
			print HT "Order $order\nDeny $deny\n";
			close (HT);

			if ($order eq 'deny,allow') {

				## allowing by default

				if ($deny =~ /^from 127/
				    || $deny =~ /^from localhost$/
				    || $deny =~ /^from all$/) {

					## if we are denied explicitly
					## its not ok
					ok !GET_OK "/modules/access/htaccess/index.html";

				} else {

					## otherwise, ok
					ok GET_OK "/modules/access/htaccess/index.html";

				}
			} else {

				## if denying by default
				## there is no 'Allow' directive, so
				## everything is denied.
				ok !GET_OK "/modules/access/htaccess/index.html";

			}

			open (HT, ">$dir/.htaccess");
			print HT "Order $order\nAllow $allow\nDeny $deny\n";
			close (HT);

			if ($order eq 'deny,allow') {

				## allowing by default

				if ($allow =~ /^from 127/
				    || $allow =~ /^from localhost$/
				    || $allow =~ /^from all$/) {

					## we are explicitly allowed
					## so it is ok.
					ok GET_OK "/modules/access/htaccess/index.html";

				} elsif ($deny =~ /^from 127/
				    || $deny =~ /^from localhost$/
				    || $deny =~ /^from all$/) {

					## if we are not explicitly allowed
					## and are explicitly denied,
					## we are denied access.
					ok !GET_OK "/modules/access/htaccess/index.html";

				} else {

					## if we are not explicity allowed
					## or explicitly denied,
					## we get access.
					ok GET_OK "/modules/access/htaccess/index.html";

				}
			} else {

				## denying by default

				if ($deny =~ /^from 127/
				    || $deny =~ /^from localhost$/
				    || $deny =~ /^from all$/) {

					## if we are explicitly denied,
					## we get no access.
					ok !GET_OK "/modules/access/htaccess/index.html";

				} elsif ($allow =~ /^from 127/
				    || $allow =~ /^from localhost$/
				    || $allow =~ /^from all$/) {

					## if we are not explicitly denied
					## and are explicitly allowed,
					## we get access.
					ok GET_OK "/modules/access/htaccess/index.html";

				} else {

					## if we are not explicitly denied
					## and not explicitly allowed,
					## we get no access.
					ok !GET_OK "/modules/access/htaccess/index.html";

				}
			}
		}
	}
}
