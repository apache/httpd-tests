my $caroot = $ENV{SSL_CA_ROOT};

if (! -d $caroot) {
    print <<EOT
Status: 500 Internal Server Error
Content-Type: text/plain

Cannot find CA root at "$ENV{SSL_CA_ROOT}";
EOT
   ;        
   print STDERR "SSL_CA_ROOT env var not set or can't find CA root.\n";
   exit(1);
}

chdir($caroot);
    
print <<EOT
Content-Type: application/ocsp-response

EOT
;

exec("openssl ocsp -CA certs/ca.crt ".
     "-index index.txt ".
     "-rsigner certs/server.crt ".
     "-rkey keys/server.pem ".
     "-reqin - -respout -");
