use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 9, need_php;

ok t_cmp(GET_BODY("/php/safemode/system.php"),
         "HelloWorld\n");

ok t_cmp(GET_BODY("/php/safemode/putenv.php"), 
         "HelloWorld",
         "testing for unrestricted envvar access");

ok t_cmp(GET_BODY("/php/safemode/badenv.php"), "",
         "testing for restricted envvar access");

ok t_cmp(GET_BODY("/php/safemode/protected.php"),
         "", 
         "testing for explicitly restricted envvar access");

if (-r "/etc/passwd") {
    ok t_cmp(GET_BODY("/php/safemode/readpass.php"),
             "",
             "testing that open_basedir is respected");
} else {
    skip "Can't test inability to read /etc/passwd", 1;
}

ok t_cmp(GET_BODY("/php/safemode/readfile.php"), 
         "This is Content.\n",
         "testing that readfile is not restricted");

ok t_cmp(GET_BODY("/php/safemode/nofile/readfile.php"),
         "", "testing that open_basedir is respected");

ok t_cmp(GET_BODY("/php/safemode/noexec/system.php"),
         "", "testing that system() is restricted");

ok t_cmp(GET_BODY("/php/safemode/error/mail.php"),
         qr/Warning.*SAFE MODE.*OK/s,
         "testing that the fifth parameter to mail() is restricted");

