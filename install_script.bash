#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]
  then echo -e"${RED} Please run as root${NC}"
  exit
fi


echo -e "${GREEN}Hi, this script installs a LAMP-Stack with the latest Drupal-WissKI for you!${NC}"
sleep 5

echo -e "${YELLOW}Is this an installation on a localhost? (Y/n)${NC}"
read ISLOCALHOST
if [[ $ISLOCALHOST == 'y' ]] || [[ $ISLOCALHOST == 'Y' ]] || [[ -z $ISLOCALHOST ]]
then 
    export LOCALHOST=true
fi

# update packages
echo -e "${GREEN}Update package manager.${NC}"

apt update;

# install packages
echo -e "${GREEN}Install necessary packages.${NC}"

apt install apache2 \
            composer \
            git \
            libapache2-mod-php \
            mariadb-server \
            php7.4 \
            php7.4-curl \
            php7.4-gd \
            php7.4-json \
            php7.4-mbstring \
            php7.4-mysqli \
            php7.4-xml \
            php7.4-zip \
            wget \
            unzip -y;


# add php configuration via wisski.ini
echo -e "${YELLOW}Add PHP configuration in /etc/php/7.4/cli/conf.d/wisski.ini${NC}"

echo "file_uploads = On
allow_url_fopen = On
memory_limit = 256M
upload_max_filesize = 20M
max_execution_time = 60
date.timezone = Europe/Berlin
max_input_nesting_level = 640" > /etc/php/7.4/apache2/conf.d/wisski.ini

# enable mod-rewrite 
echo -e "${GREEN}enable mod_rewrite for apache2.${NC}"
a2enmod rewrite;

# restart apache
echo -e "${GREEN}Restart apache server${NC}"
systemctl restart apache2

# configure site

finished=false
while [ $finished == false ]
do
    echo -e "${GREEN}What is the name of your Website (WITHOUT \"https://www.\" etc. like \"example.com\")?${NC}"
    echo -e "${YELLOW}It will be used as webroot dir at /var/www/html/ and as your servername.${NC}"
    while [[ -z $WEBSITENAME ]]
    do
        read WEBSITENAME
        if [[ -z $WEBSITENAME ]]
        then
            echo -e "${RED}Websitename can not be emtpy! Please enter a websitename!${NC}"
        fi
    done
    echo -e "${GREEN}Enter your server admin email adress:${NC}"
    while [[ -z $SERVERADMINEMAIL ]]
    do
        read SERVERADMINEMAIL
        if [[ -z $SERVERADMINEMAIL ]]
        then
            echo -e "${RED}Server admin mail adress can not be emtpy! Please enter an amdin mail adress!${NC}"
        fi
    done
    echo -e "${YELLOW}Websitename: ${WEBSITENAME}${NC}"
    echo -e "${YELLOW}Server admin mail: ${SERVERADMINEMAIL}${NC}"
    echo -e "${YELLOW}Is that correct? (Y/n)"
    read SURE
    if [[ $SURE == 'y' ]] || [[ $SURE == 'Y' ]] || [[ -z $SURE ]]
    then 
        export WEBSITENAME
        export SERVERADMINEMAIL
        finished=true
    else
        echo -e "${RED}Okay then...?${NC}"
    fi
done

#add websitename to hosts

if [[ $LOCALHOST ]]
echo -e "${GREEN}Since, you are on localhost, I try to add \"127.0.0.1   ${WEBSITENAME}\" to /etc/hosts.${NC}"
then
    if grep -q "${WEBSITENAME}" "/etc/hosts";
    then 
        echo -e "${RED}Entry \"127.0.0.1   ${WEBSITENAME}\" already in /etc/hosts${NC}"
    else
        echo -e "${YELLOW}ADD $WEBSITENAME to /etc/hosts, because you are on a local host!${NC}"
        echo "127.0.0.1   ${WEBSITENAME}" >> /etc/hosts
    fi

    
fi

# add apache site
echo -e "${YELLOW}Write server configuration in /etc/apache2/sites-available/${WEBSITENAME}.conf.${NC}"
echo "<VirtualHost *:80>
    ServerAdmin ${SERVERADMINEMAIL}
    DocumentRoot \"/var/www/html/${WEBSITENAME}/web\"
    ServerName www.${WEBSITENAME}
    ServerAlias ${WEBSITENAME}
    ErrorLog \"/var/log/apache2/drupal.local-error_log\"
    CustomLog \"/var/log/apache2/drupal.local-access_log\" common
        <Directory /var/www/html/$WEBSITENAME/web>
        Options FollowSymlinks
        AllowOverride All
        Require all granted
        RewriteEngine on
        RewriteBase /
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
    </Directory>
</VirtualHost>" > /etc/apache2/sites-available/${WEBSITENAME}.conf

# enable site
echo -e "${GREEN}Enable site ${WEBSITENAME}${NC}"
a2ensite ${WEBSITENAME}

# restart apache
echo -e "${GREEN}Restart apache server${NC}"
systemctl restart apache2

# run mariadb security script
echo -e "${YELLOW}Making Mariadb secure. Please note your root credentials!${NC}"
mysql_secure_installation;

# create database 
echo -e "${YELLOW}Create Database for Drupal. Please note your inputs, they will be needed in a moment.${NC}"
echo -e "${YELLOW}Enter name of the Database, you want to create:${NC}"
read DB
echo -e "${YELLOW}Enter name of the user you want to create:${NC}"
read USER
echo -e "${YELLOW}Enter passwort of that user:${NC}"
read USERPW

mysql -e "CREATE DATABASE ${DB} ;"
mysql -e "CREATE USER ${DB}@localhost IDENTIFIED BY '${USERPW}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo -e "${GREEN}Created ${DB} database with ${USER} identified by ${USERPW} ${NC}"

# install drupal with drush
echo -e "${GREEN}We are ready to install Drupal! It will be installed under /var/www/html/$WEBSITENAME.${NC}"

cd /var/www/html/ 
echo -e "${YELLOW}Composer will scold you for being root, ignore it, it will be taken care of later.${NC}"
composer create-project drupal/recommended-project $WEBSITENAME


echo -e "${GREEN}Installing WissKI with some modules (you have to activate them later).${NC}"
cd $WEBSITENAME
composer require drupal/colorbox drupal/devel drush/drush drupal/imagemagick drupal/wisski 

echo -e "${GREEN}Get necessary libraries.${NC}"
mkdir -p web/libraries
wget https://github.com/jackmoore/colorbox/archive/refs/heads/master.zip -P web/libraries/
unzip web/libraries/master.zip -d web/libraries/
mv web/libraries/colorbox-master web/libraries/colorbox

chown -R www-data:www-data ../$WEBSITENAME
chmod 775 -R ../$WEBSITENAME

echo -e "${GREEN}Thats it! You can now visit http://${WEBSITENAME} and install Drupal!${NC}"
