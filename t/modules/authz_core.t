use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_write_file);
use File::Spec;

# test RequireAll/RequireAny containers and AuthzMerging

plan tests => 165,
              need need_lwp,
              need_module('mod_authn_core'),
              need_module('mod_authz_core'),
              need_module('mod_authz_host'),
              need_min_apache_version('2.3.6');


my $text = '';

sub check
{
    my $rc = shift;
    my $path = shift;

    my @args;
    foreach my $e (@_) {
        push @args, "X-Allowed$e" => 'yes';
    }
    my $res = GET "/authz_core/$path", @args;
    ok($res->code, $rc, "$text: $path @_");
}

sub write_htaccess
{
    my $path = shift;
    my $merging = shift || "";
    my $container = shift || "";

    $text = "$path $merging $container @_";

    my $content = "";
    $content .= "AuthMerging $merging\n" if $merging;

    if ($container) {
        $content .= "<Require$container>\n";
        foreach (@_) {
            my $req = $_;
            my $not = "";
            if ($req =~ s/^\!//) {
                $not = 'not';
            }
            if ($req =~ /all/) {
                $content .= "Require $not $req\n";
            }
            else {
                $content .= "Require $not env allowed$req\n";
            }
        }
        $content .= "</Require$container>\n";
    }

    my $file = File::Spec->catfile(Apache::Test::vars('documentroot'),
        "/authz_core/$path/.htaccess");
    t_write_file($file, $content);
}

write_htaccess("a/", undef, 0);
check(200, "a/");
check(200, "a/", 1);
check(200, "a/", 2);
check(200, "a/", 1, 2);
check(200, "a/", 3);


write_htaccess("a/", undef, "Any", 1, 2);
check(403, "a/");
check(200, "a/", 1);
check(200, "a/", 2);
check(200, "a/", 1, 2);
check(403, "a/", 3);
  write_htaccess("a/b/", undef, "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Off", "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Or", "Any", 2, 3);
  check(403, "a/b/");
  check(200, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "And", "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 1, 2);
  check(200, "a/b/", 1, 3);
  check(200, "a/b/", 2, 3);
  write_htaccess("a/b/", undef, "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Off", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Or", "All", 3, 4);
  check(403, "a/b/");
  check(200, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 2, 3);
  check(200, "a/b/", 3, 4);
  check(403, "a/b/", 3);
  check(403, "a/b/", 4);
  write_htaccess("a/b/", "And", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 1, 2);
  check(403, "a/b/", 1, 3);
  check(200, "a/b/", 2, 3);


write_htaccess("a/", undef, "All", 1, "!2");
check(403, "a/");
check(200, "a/", 1);
check(403, "a/", 2);
check(403, "a/", 1, 2);
check(403, "a/", 3);
  write_htaccess("a/b/", undef, "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Off", "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Or", "Any", 3, 4);
  check(403, "a/b/");
  check(200, "a/b/", 1);
  check(403, "a/b/", 1, 2);
  check(200, "a/b/", 1, 2, 3);
  check(200, "a/b/", 1, 2, 4);
  check(200, "a/b/", 4);
  write_htaccess("a/b/", "And", "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 1, 2);
  check(200, "a/b/", 1, 3);
  check(403, "a/b/", 2, 3);
    # should not inherit AuthMerging And from a/b/
    write_htaccess("a/b/c/", undef, "Any", 4);
    check(403, "a/b/c/", 1, 3);
    check(200, "a/b/c/", 4);
    check(200, "a/b/c/", 1, 2, 4);
  write_htaccess("a/b/", undef, "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Off", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Or", "All", 3, 4);
  check(403, "a/b/");
  check(200, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 2, 3);
  check(200, "a/b/", 3, 4);
  check(403, "a/b/", 3);
  check(403, "a/b/", 4);
  write_htaccess("a/b/", "And", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 1, 2);
  check(403, "a/b/", 1, 3);
  check(403, "a/b/", 2, 3);


write_htaccess("a/", undef, "All", 1, 2);
check(403, "a/");
check(403, "a/", 1);
check(403, "a/", 2);
check(200, "a/", 1, 2);
  write_htaccess("a/b/", undef, "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Off", "Any", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(200, "a/b/", 2);
  check(200, "a/b/", 3);
  write_htaccess("a/b/", "Or", "Any", 3, 4);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(200, "a/b/", 1, 2);
  check(200, "a/b/", 3);
  check(200, "a/b/", 4);
  write_htaccess("a/b/", "And", "Any", 3, 4);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 4);
  check(403, "a/b/", 1, 2);
  check(200, "a/b/", 1, 2, 3);
  check(200, "a/b/", 1, 2, 4);
  check(403, "a/b/", 1, 3, 4);
  write_htaccess("a/b/", undef, "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Off", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(200, "a/b/", 2, 3);
  check(403, "a/b/", 1, 3);
  write_htaccess("a/b/", "Or", "All", 3, 4);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 4);
  check(403, "a/b/", 2, 3);
  check(200, "a/b/", 3, 4);
  check(200, "a/b/", 1, 2);
  write_htaccess("a/b/", "And", "All", 2, 3);
  check(403, "a/b/");
  check(403, "a/b/", 1);
  check(403, "a/b/", 2);
  check(403, "a/b/", 3);
  check(403, "a/b/", 1, 2);
  check(403, "a/b/", 1, 3);
  check(403, "a/b/", 2, 3);
  check(200, "a/b/", 1, 2, 3);

