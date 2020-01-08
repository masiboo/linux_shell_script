#!/bin/bash -x
# Run this script as sudo ./odoo_install.bash usernamei

RED='\033[0;31m' # red color
NC='\033[0m' # No Color

if [[ "$1" != "" ]]; then
   user="$1"
else
    echo -e " ${RED} You must enter the current user name as a script parameter. E.G run the script as sudo ./odoo_install.bash usernamei  ${NC}"
    exit
fi

# we update and upgrade apt-get
apt-get update
apt-get -y upgrade

# install python3-pip and libpq-dev
apt install git python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less  libpq-dev python-dev npm node-less -y

# install dependencies using pip3
pip3 install Babel decorator docutils ebaysdk feedparser gevent greenlet html2text Jinja2 lxml Mako MarkupSafe mock num2words ofxparse passlib Pillow psutil psycogreen psycopg2 pydot pyparsing PyPDF2 pyserial python-dateutil python-openid pytz pyusb PyYAML qrcode reportlab requests six suds-jurko vatnumber vobject Werkzeug XlsxWriter xlwt xlrd

# install node-less and less-plugin-clean-css
npm install -g less less-plugin-clean-css

# install software-properties-common
apt-get install software-properties-common -y

# Enable PostgreSQL Apt Repository
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt-get update

# insall postpost
apt-get install postgresql-9.6 -y

# Create Database user for Odoo
sudo -u postgres createuser -s odoo
sudo -u postgres createuser -s $user

# odoo user home and group

id -u odoo > /dev/null 2>&1;

if [ "$?" = 0 ]; then
    echo "oddo exist no need to add again"
else
    adduser --system --home=/opt/odoo --group odoo
fi

# write a local odoo config file 
cat > odoo.conft <<EOL
[options]

; This is the password that allows database operations:

; admin_passwd = admin

db_host = False

db_port = False

db_user = odoo

db_password = False

logfile = /var/log/odoo/odoo-server.log

addons_path = /opt/odoo/addons,/opt/odoo/odoo/addons

EOL

# copy to /etc/ and change ownership
mv odoo.conft /etc/
chown odoo: /etc/odoo.conft

# cloan odoo 12
git clone -b 12.0 --single-branch  https://www.github.com/odoo/odoo

mv ./odoo /opt/odoo/
chown -R odoo /opt/odoo/odoo

mkdir /var/log/odoo
chown -R odoo:root /var/log/odoo
apt-get -f install -y

# wkhtmltox has dependency on libpng12. So downlaod it and install it as well.
wget http://security.ubuntu.com/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1.1_amd64.deb
wget https://builds.wkhtmltopdf.org/0.12.1.3/wkhtmltox_0.12.1.3-1~bionic_amd64.deb

apt install ./libpng12-0_1.2.54-1ubuntu1.1_amd64.deb -y
apt install ./wkhtmltox_0.12.1.3-1~bionic_amd64.deb -y
rm ./libpng12-0_1.2.54-1ubuntu1.1_amd64.deb ./wkhtmltox_0.12.1.3-1~bionic_amd64.deb

cp /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage
cp /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf

# clone required and build stuffs
cd /usr/local/lib/
git clone https://github.com/sass/sassc.git --depth 1
git clone https://github.com/sass/libsass.git --branch 3.4-stable --depth 1
git clone https://github.com/sass/sass-spec.git --depth=1

echo 'SASS_LIBSASS_PATH="/usr/local/lib/libsass"' | sudo tee -a /etc/environment
source /etc/environment


make -C libsass
make -C sassc
make -C sassc install

# Run Odoo Server
cd /opt/odoo/odoo
# we should run odoo as local user
sudo -u $user ./odoo-bin

