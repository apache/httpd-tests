package Bundle::ApacheTest;

$VERSION = '0.01';

1;

__END__

=head1 NAME

Bundle::ApacheTest - A bundle to install all Apache-Test related modules

=head1 SYNOPSIS

 perl -MCPAN -e 'install Bundle::ApacheTest'

=head1 CONTENTS

Crypt::SSLeay      - For https support

Devel::CoreStack   - For getting core stack info

Devel::Symdump     - For, uh, dumping symbols

Digest::MD5        - Needed for Digest authentication

URI                - There are URIs everywhere

Net::Cmd           - For libnet

MIME::Base64       - Used in authentication headers

HTML::Tagset       - Needed by HTML::Parser

HTML::Parser       - Need by HTML::HeadParser

HTML::HeadParser   - To get the correct $res->base

LWP                - For libwww-perl

IPC::Run3          - Used in Apache::TestSmoke

=head1 DESCRIPTION

This bundle lists all the CPAN modules used by Apache-Test.

=cut
