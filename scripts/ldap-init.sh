#!/bin/bash -ex
DOCKER=${DOCKER:-`which docker 2>/dev/null || which podman 2>/dev/null`}
cid1=`${DOCKER} run -d -p 8389:389 httpd_ldap`
cid2=`${DOCKER} run -d -p 8390:389 httpd_ldap`
sleep 5

# Disable anonymous bind; must be done as an authenticated local user
# hence via ldapadd -Y EXTERNAL within the container.
${DOCKER} exec -i $cid1 /usr/bin/ldapadd -Y EXTERNAL -H ldapi:// < scripts/non-anon.ldif
${DOCKER} exec -i $cid2 /usr/bin/ldapadd -Y EXTERNAL -H ldapi:// < scripts/non-anon.ldif

ldapadd -x -H ldap://localhost:8389 -D cn=admin,dc=example,dc=com -w travis < scripts/httpd.ldif
ldapadd -x -H ldap://localhost:8390 -D cn=admin,dc=example,dc=com -w travis < scripts/httpd-sub.ldif
