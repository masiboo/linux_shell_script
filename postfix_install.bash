#!/bin/bash
mail_domain="koodin.guru"
postfix_db_user="mail"
postfix_db_password="mypass"
postfix_db_name="mail"
postfix_db_host="127.0.0.1"
postfix_domain="mail.koodi.guru"
postfixadmin_domain="koodi.guru"
postfixadmin_setup_password=""
webmail_domain="koodin.guru"
mysql_root="myprootpass"
postfix_version="3.2"
postfix_file="postfixadmin-${postfix_version}.tar.gz"
roundcube_version="1.3.9"
roundcube_file="roundcubemail-${roundcube_version}.tar.gz"
roundcube_domain="koodin.guru"
roundcube_db_password="mypass"
roundcube_des_key="mypass"

echo "postfix postfix/mailname string ${postfix_domain}" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections


echo "mysql-server mysql-server/root_password password ${mysql_root}" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password ${mysql_root}" | debconf-set-selections
debconf-set-selections <<< 'mysql-server mysql-server/root_password password ${mysql_root}'
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password ${mysql_root}'
apt-get -y install mysql-server

mysql -p${mysql_root} -e "CREATE DATABASE ${postfix_db_name};"
mysql -p${mysql_root} -e "CREATE USER ${postfix_db_user}@localhost IDENTIFIED BY '${postfix_db_password}';"
mysql -p${mysql_root} -e "GRANT ALL PRIVILEGES ON ${postfix_db_name}.* TO '${postfix_db_user}'@'localhost';"
mysql -p${mysql_root} -e "FLUSH PRIVILEGES;"

apt-get install -y postfix nginx php-fpm dovecot-core \
    dovecot-mysql postfix-mysql libsasl2-modules libsasl2-modules-sql \
    libgsasl7 libauthen-sasl-cyrus-perl sasl2-bin libpam-mysql memcached \
    dovecot-imapd php-mysql php-mbstring php-imap amavisd-new \
    postfix-policyd-spf-python certbot

mkdir /var/www/certs

wget "https://github.com/postfixadmin/postfixadmin/archive/${postfix_file}" && tar -xzf "${postfix_file}" && mv "postfixadmin-postfixadmin-${postfix_version}" /var/www/postfixadmin && chown -R www-data: /var/www/postfixadmin
wget "https://github.com/roundcube/roundcubemail/releases/download/${roundcube_version}/${roundcube_file}" && tar -xzf "${roundcube_file}" && mv "roundcubemail-${roundcube_version}" /var/www/roundcube && chown -R www-data: /var/www/roundcube
mv /var/www/roundcube/config/config.inc.php.sample /var/www/roundcube/config/config.inc.php

mkdir -p /var/spool/postfix/var/run/saslauthd
usermod -G sasl postfix
mkdir /var/www/postfixadmin/templates_c

chown -R www-data: /var/www/postfixadmin/templates_c

cp ./postfix_main.cf /etc/postfix/main.cf
cp ./postfix_master.cf /etc/postfix/master.cf
cp ./postfixadmin_config.local.php /var/www/postfixadmin/config.local.php
cp ./nginx_pre_postihallinta.domain.dom "/etc/nginx/sites-available/${postfixadmin_domain}"
ln -s "/etc/nginx/sites-available/${postfixadmin_domain}" "/etc/nginx/sites-enabled/${postfixadmin_domain}"
cp ./nginx_pre_roundcube.domain.dom "/etc/nginx/sites-available/${roundcube_domain}"
ln -s "/etc/nginx/sites-available/${roundcube_domain}" "/etc/nginx/sites-enabled/${roundcube_domain}"
systemctl reload nginx

cp ./postfix_mysql_virtual_alias_maps.cf /etc/postfix/mysql_virtual_alias_maps.cf
cp ./postfix_mysql_virtual_domains_maps.cf /etc/postfix/mysql_virtual_domains_maps.cf
cp ./postfix_mysql_virtual_mailbox_maps.cf /etc/postfix/mysql_virtual_mailbox_maps.cf
cp ./postfix_mysql_virtual_mailbox_limit_maps.cf /etc/postfix/mysql_virtual_mailbox_limit_maps.cf
cp ./postfix_mysql_relay_domains_maps.cf /etc/postfix/mysql_relay_domains_maps.cf
cp ./postfix_mysql_virtual_alias_domainaliases_maps.cf /etc/postfix/mysql_virtual_alias_domainaliases_maps.cf
cp ./postfix_mysql_virtual_mailbox_domainaliases_maps.cf /etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf

cp ./postfix_helo.regexp /etc/postfix/helo.regexp
cp ./sasl_saslauthd /etc/default/saslauthd
cp ./sasl_smtpd.conf /etc/postfix/sasl/smtpd.conf
cp ./pam_smtp /etc/pam.d/smtp
cp ./amavis_50-user /etc/amavis/conf.d/50-user
cp ./amavis_05-node_id /etc/amavis/conf.d/05-node_id
cp ./dovecot_dovecot.conf /etc/dovecot/dovecot.conf
cp ./dovecot_10-master.conf /etc/dovecot/conf.d/10-master.conf
cp ./dovecot_10-mail.conf /etc/dovecot/conf.d/10-mail.conf
cp ./dovecot_10-auth.conf /etc/dovecot/conf.d/10-auth.conf
cp ./dovecot_15-lda.conf /etc/dovecot/conf.d/15-lda.conf
cp ./dovecot_dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext

cp ./nginx_cert_domain "/etc/nginx/sites-available/${postfix_domain}"
ln -s "/etc/nginx/sites-available/${postfix_domain}" "/etc/nginx/sites-enabled/${postfix_domain}"
systemctl reload nginx
letsencrypt certonly --non-interactive --email asiakaspalvelimet@netitys.fi --agree-tos --webroot -w /var/www/certs/ -d "${postfix_domain}"



chmod -R 600 /etc/postfix


apt-get autoremove -y \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/ */tmp/* /var/tmp/ */opt/packages/*



openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096

groupadd vmail
mkdir -p /srv/var/vmail
useradd -m -g vmail -u 150 -d /srv/var/vmail -s /bin/bash vmail
chmod 770 /srv/var/vmail/
chown vmail: /srv/var/vmail
mkdir -p /srv/var/db/dkim

sed -i \
 -e "s/MYHOSTNAME/${postfix_domain}/g" \
 /etc/postfix/main.cf

sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_alias_maps.cf
sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_domains_maps.cf
sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_mailbox_maps.cf
sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_mailbox_limit_maps.cf
sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_alias_domainaliases_maps.cf
sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 -e "s/DBDOMAIN/${postfix_db_host}/g" \
 /etc/postfix/mysql_virtual_mailbox_domainaliases_maps.cf

sed -i \
 -e "s/DATABASE_USER/${postfix_db_user}/g" \
 -e "s/DATABASE_PASSWORD/${postfix_db_password}/g" \
 -e "s/DATABASE_NAME/${postfix_db_name}/g" \
 -e "s/DATABASE_HOST/${postfix_db_host}/g" \
 -e "s/ADMIN_EMAIL/${postfixadmin_admin_email}/g" \
 -e "s/ABUSE/${postfixadmin_abuse}/g" \
 -e "s/HOSTMASTER/${postfixadmin_hostmaster}/g" \
 -e "s/POSTMASTER/${postfixadmin_postmaster}/g" \
 -e "s/WEBMASTER/${postfixadmin_webmaster}/g" \
 /var/www/postfixadmin/config.local.php

sed -i \
 -e "s/\$CONF[\'configured\'] = false//\$CONF[\'configured\'] = true/g" \
 /var/www/postfixadmin/config.inc.php

sed -i \
 -e "s/postfixadmin_domain/${postfixadmin_domain}/g" \
 "/etc/nginx/sites-available/${postfixadmin_domain}"

sed -i \
 -e "s/cert_domain/${postfix_domain}/g" \
 "/etc/nginx/sites-available/${postfix_domain}"

sed -i \
 -e "s/SQL_USER/${postfix_db_user}/g" \
 -e "s/SQL_PASSWORD/${postfix_db_password}/g" \
 -e "s/SQL_DATABASE/${postfix_db_name}/g" \
 /etc/postfix/sasl/smtpd.conf

sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWD/${postfix_db_password}/g" \
 -e "s/DB/${postfix_db_name}/g" \
 /etc/pam.d/smtp

sed -i \
 -e "s/POSTMASTER/${postfixadmin_postmaster}/g" \
 /etc/dovecot/conf.d/15-lda.conf

sed -i \
 -e "s/USER/${postfix_db_user}/g" \
 -e "s/PASSWORD/${postfix_db_password}/g" \
 -e "s/DBNAME/${postfix_db_name}/g" \
 /etc/dovecot/dovecot-sql.conf.ext

sed -i \
 -e "s/DES/${roundcube_des_key}/g" \
 -e "s/DOMAIN/${roundcube_domain}/g" \
 -e "s/PASSWORD/${roundcube_db_password}/g" \
 /var/www/roundcube/config/config.inc.php

sed -i \
 -e "s/#ssl/ssl/g" \
 -e "s/\/etc\/dovecot\/private\/dovecot\.pem/\/etc\/letsencrypt\/live\/${postfix_domain}\/fullchain\.pem/g" \
 -e "s/\/etc\/dovecot\/private\/dovecot\.key/\/etc\/letsencrypt\/live\/${postfix_domain}\/privkey\.pem/g" \
 /etc/dovecot/conf.d/10-ssl.conf

sed -i \
 -e "s/HOSTNAME/${mail_domain}/g"\
 /etc/amavis/conf.d/05-node_id

# domains = ""
# while IFS='=' read -r name domain ; do
#  if [[ $name == 'DOMAIN_'* ]]; then
#    domains += "\"$domain\","
#    echo 'dkim_key("${domain}", "dkim", "/var/db/dkim/${domain}.pem");' >> /etc/amavis/conf.d/50-user
#  fi
#done < <(env)
#domains = ${domains::-1}



echo '@local_domains_maps = ( ['${mail_domain}'] ); 1;' >> /etc/amavis/conf.d/50-user
echo 'dkim_key("'${mail_domain}'", "dkim", "/var/db/dkim/'${mail_domain}'.pem");' >> /etc/amavis/conf.d/50-user
amavisd-new genrsa /srv/var/db/dkim/${mail_domain}
service amavis restart

chown vmail: /var/run/dovecot/auth-userdb

#systemctl reload nginx
#letsencrypt certonly --non-interactive --email asiakaspalvelimet@netitys.fi --agree-tos --webroot -w /var/www/postfixadmin/ -d "${postfixadmin_domain}"
#cp ./nginx_postihallinta.domain.dom "/etc/nginx/sites-available/${postfixadmin_domain}"
#sed -i \
# -e "s/postfixadmin_domain/${postfixadmin_domain}/g" \
# "/etc/nginx/sites-available/${postfixadmin_domain}"

systemctl reload nginx


systemctl restart postfix
systemctl restart dovecot

#mailq
#postfix flush
#amavisd-new genrsa alpha.tilaajavastuu.io
#chmod 600 alpha.tilaajavastuu.io 
#chown amavis: alpha.tilaajavastuu.io 
#mv alpha.tilaajavastuu.io /var/db/dkim/
#amavisd-new showkeys
#mv /var/db/dkim/alpha.tilaajavastuu.io /var/db/dkim/alpha.tilaajavastuu.io.pem
#amavisd-new showkeys
#service amavis restart
#amavisd-new testkeys
#dig dkim._domainkey.alpha.tilaajavastuu.fi
#vim /etc/amavis/conf.d/50-user 
#service amavis restart
#amavisd-new testkeys

