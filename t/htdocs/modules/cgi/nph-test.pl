#!/home/stas/perl/5.8.1-ithread/bin/perl5.8.1
# WARNING: this file is generated, do not edit
# 01: Apache-Test/lib/Apache/TestConfig.pm:743
# 02: Apache-Test/lib/Apache/TestConfig.pm:821
# 03: Apache-Test/lib/Apache/TestMM.pm:92
# 04: Makefile.PL:26

BEGIN { eval { require blib; } }

%Apache::TestConfig::Argv = qw(apxs /home/stas/httpd/prefork/bin/apxs);
print "HTTP/1.0 200 OK\r\n";
print join("\n",
     'Content-type: text/html',
     'Pragma: no-cache',
     'Cache-control: must-revalidate, no-cache, no-store',
     'Expires: -1',
     "\n");

print "ok\n";
