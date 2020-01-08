#!/bin/bash -x

local_ip="54.72.122.252"
user_name="ubuntu"
internet_site="Internet Site"
email_host="islam.koodi.guru"

sudo apt update
sudo apt list --upgradable
: '
sudo apt-get install -y postfix

sudo postconf -e "smtp_tls_security_level = may"
sudo postconf -e "smtpd_tls_security_level = may"
sudo postconf -e "smtp_tls_note_starttls_offer = yes"
sudo postconf -e "smtpd_tls_key_file = /etc/ssl/private/server.key"
sudo postconf -e "smtpd_tls_cert_file = /etc/ssl/certs/server.crt"
sudo postconf -e 'smtpd_tls_CAfile = /etc/ssl/certs/cacert.pem'
sudo postconf -e "smtpd_tls_loglevel = 1"
sudo postconf -e "smtpd_tls_received_header = yes"
sudo postconf -e "myhostname = ${email_host}"
sudo postconf -e "mydestination = ${email_host} localhost.koodi.guru, localhost"
sudo postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 ${local_ip}/24"
sudo postconf -e "mailbox_size_limit = 0"
sudo postconf -e "mailname = ${email_host}"
sudo postconf -e "main_mailer_type = Internet Site"
sudo postconf -e "recipient_delimiter = +"
sudo postconf -e "inet_interfaces = all"
sudo postconf -e "smtpd_sasl_local_domain = "
sudo postconf -e "smtpd_sasl_auth_enable = yes"
sudo postconf -e "smtpd_sasl_security_options = noanonymous"
sudo postconf -e "broken_sasl_auth_clients = yes"
sudo postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject _unauth_destination"
sudo postconf -e "smtpd_tls_auth_only = no"
sudo postconf -e "smtp_tls_security_level = may"
sudo postconf -e "smtpd_tls_security_level = may"
sudo postconf -e "smtpd_tls_session_cache_timeout = 3600s"
sudo postconf -e "tls_random_source = dev:/dev/urandom"
'
# now restart postfix service
#sudo systemctl restart postfix.service
# copy key and cert to the correct location
sudo cp ./server.key /etc/ssl/private/
sudo cp ./server.crt /etc/ssl/certs/

# Postfix supports two SASL implementations Cyrus SASL and Dovecot SASL. To enable Dovecot SASL the dovecot-core package is need to be installed
sudo apt install -y dovecot-core

# add mail host name at hostname
echo "127.0.0.1 ${email_host}" | sudo tee /etc/hostname 

# update dovecot config
sudo sed -i '0,/\# Postfix smtp-auth/s/\# Postfix smtp-auth/ \# Postfix smtp-auth \n  unix_listener \/var\/spool\/postfix\/private\/auth \{ \n mode = 0660 \n user = postfix \n group = postfix \n \} /' /etc/dovecot/conf.d/10-master.conf
sudo sed -i '0,/auth_mechanisms = plain/s/auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
#sudo sed -i 's=<\(/etc/dovecot/private/dovecot\.pem\)=\1=1' /etc/dovecot/conf.d/10-ssl.conf 
#sudo sed -i 's=<\(/etc/dovecot/private/dovecot.key\)=\1=1' /etc/dovecot/conf.d/10-ssl.conf 

# dovecot service restart
sudo systemctl restart dovecot.service

# Postfix for SMTP-AUTH is using the mail-stack-delivery package
sudo apt install -y mail-stack-delivery

# restart postfix service
sudo systemctl restart postfix.service

