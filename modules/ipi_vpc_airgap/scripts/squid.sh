#!/bin/bash

# Apply the latest security patches
dnf update -y --security

# Install and start Squid
dnf install -y squid firewalld vim policycoreutils-python-utils
systemctl enable --now firewalld
sleep 5

# Enable firewalld redirects
 firewall-cmd --add-forward-port=port=80:proto=tcp:toport=3129
 firewall-cmd --add-forward-port=port=443:proto=tcp:toport=3130
 firewall-cmd --add-port=443/tcp --permanent
 firewall-cmd --add-port=80/tcp --permanent
 firewall-cmd --runtime-to-permanent

iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3129
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3130       

cp -a /etc/squid /etc/squid_orig

# Create cache directories, set perms and set contexts
mkdir /var/spool/squid
mkdir /var/cache/squid
semanage fcontext -a -t squid_cache_t "/var/spool/squid(/.*)?"
restorecon -FRvv /var/spool/squid
chown -R squid:squid /var/spool/squid
chown -R squid:squid /var/cache/squid

# SELinux Configuration: Add additional squid ports to selinux
semanage port -a -t squid_port_t -p tcp 3129-3130

# Create a SSL certificate for the SslBump Squid module
mkdir /etc/squid/ssl
openssl genrsa -out /etc/squid/ssl/squid.key 4096
openssl req -new -key /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.csr -subj "/C=US/ST=VA/L=squid/O=squid/CN=squid"
openssl x509 -req -days 3650 -in /etc/squid/ssl/squid.csr -signkey /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt
cat /etc/squid/ssl/squid.key /etc/squid/ssl/squid.crt >> /etc/squid/ssl/squid.pem

chmod 600 /etc/squid/ssl/squid.pem
restorecon -FRvv /etc/squid/ssl/squid.pem

echo '.amazonaws.com' > /etc/squid/whitelist.txt
echo '.cloudfront.net' >> /etc/squid/whitelist.txt
# The following is for access to the RHUI repositories hosted in AWS.
echo '.aws.ce.redhat.com' >> /etc/squid/whitelist.txt

cat > /etc/squid/squid.conf << EOF

visible_hostname squid
cache deny all

# Log format and rotation
logformat squid %ts.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru %ssl::>sni %Sh/%<a %mt
logfile_rotate 10
debug_options rotate=10

# Handle HTTP requests
http_port 3128
http_port 3129 intercept

# Handle HTTPS requests
https_port 3130 cert=/etc/squid/ssl/squid.pem ssl-bump intercept
acl SSL_port port 443
http_access allow SSL_port
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3
ssl_bump peek step1 all

# Deny requests to proxy instance metadata
acl instance_metadata dst 169.254.169.254
http_access deny instance_metadata

# Filter HTTP requests based on the whitelist
acl allowed_http_sites dstdomain "/etc/squid/whitelist.txt"
http_access allow allowed_http_sites

# Filter HTTPS requests based on the whitelist
acl allowed_https_sites ssl::server_name "/etc/squid/whitelist.txt"
ssl_bump peek step2 allowed_https_sites
ssl_bump splice step3 allowed_https_sites
ssl_bump terminate step2 all

http_access deny all
EOF

/usr/sbin/squid -k parse && /usr/sbin/squid -k reconfigure

#/usr/lib64/squid/security_file_certgen -c -s /var/cache/squid/ssl_db -M 4MB
/usr/lib64/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB

# Start and enable squid
systemctl enable --now squid