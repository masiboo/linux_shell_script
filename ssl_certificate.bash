#!/bin/bash -x

sudo mkdir /etc/ssl/CA
sudo mkdir /etc/ssl/newcerts
sudo sh -c "echo '01' > /etc/ssl/CA/serial"
sudo touch /etc/ssl/CA/index.txt


# update openssl.cnf file
sudo sed -i '0,/\.\/demoCA/s/\.\/demoCA/\/etc\/ssl/' /etc/ssl/openssl.cnf 
sudo sed -i '0,/\$dir\/index\.txt/s/\$dir\/index\.txt/\$dir\/CA\/index\.txt/' /etc/ssl/openssl.cnf
sudo sed -i '0,/\$dir\/cacert\.pem/s/\$dir\/cacert\.pem/\$dir\/certs\/cacert\.pem/' /etc/ssl/openssl.cnf
sudo sed -i '0,/\$dir\/tsaserial/s/\$dir\/tsaserial/\$dir\/CA\/serial/' /etc/ssl/openssl.cnf
sudo sed -i '0,/\$dir\/serial/s/\$dir\/serial/\$dir\/CA\/serial/' /etc/ssl/openssl.cnf

# create the self-signed root certificate
openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650

# install the root certificate and key
sudo cp cakey.pem /etc/ssl/private/
sudo cp cacert.pem /etc/ssl/certs/

# To generate the keys for the Certificate Signing Request (CSR) run the following command
openssl genrsa -des3 -out server.key 2048

# Now create the insecure key, the one without a passphrase, and shuffle the key names
openssl rsa -in server.key -out server.key.insecure
# The insecure key is now named server.key, and we can use this file to generate the CSR without passphrase
mv server.key server.key.secure
mv server.key.insecure server.key

# To create the CSR, run the following command
openssl req -new -key server.key -out server.csr

# enter the following to generate a certificate signed by the CA TODO make file from output
sudo openssl ca -in server.csr -config /etc/ssl/openssl.cnf

read -p "Press [Enter] after saving a file server.crt  with the text -BEGIN CERTIFICATE----- XXXXX -----END CERTIFICATE----- "

sudo cp server.key  /etc/ssl/private/
sudo cp server.crt /etc/ssl/certs/

