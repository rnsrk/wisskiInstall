#!/usr/bin/env bash

# Colors for text lines
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if executer is root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root: \"sudo ./install_drupal-wisski.bash\""
  exit
fi

echo -e "${GREEN}Hi, this script installs a LAMP-Stack with the latest Drupal-WissKI for you!"
echo
sleep 3

# Check if installation is for local develepment or production
# If yes: add website name to /etc/hosts/, see section "add website to /etc/hosts"
echo -e "${YELLOW}Do you use this script to install WissKI on a local development system" 
echo -e "or on a server for production?"
echo -e "(Selecting \"for local development\" adds your domain to /etc/hosts) in a later step."
echo -e "(Selecting \"for production\" opens the possibility to use ssl.)${NC}"
echo 
PS3="I am installing option... "
options=("for local development." "for production." "I don't know, please quit.")
select opt in "${options[@]}"
do
    case $opt in
        "for local development.")
            LOCALHOST=true
            echo -e "${GREEN} Okay, will add website name to /etc/hosts later."
            break
            ;;
        "for production.")
            echo -e "${GREEN}Okay fine."
            break
            ;;
        "I don't know, please quit.")
            echo -e "${GREEN}Okay bye."
            exit 0
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo
echo -e "${GREEN}I want to check if required LAMP-Stack is installed. You need:"
echo
APTS=()

# Apache
if command -v apache2 &> /dev/null
then
    APACHE="$(apache2 -v | grep 'Server version' | cut -d':' -f 2)"
else
    APACHE='not installed'
    APTS+=( "apache2" "libapache2-mod-php" )
fi
echo -e "${GREEN}Apache2: ${APACHE}"

# Mariadb
if command -v mysql &> /dev/null
then
    MYSQL="$(mysql --version | cut -d',' -f 1)"
else
    MYSQL="not installed"
    APTS+=( "mariadb-server" )
fi
echo -e "${GREEN}MariaDB/MySQL: ${MYSQL}"

# PHP
if command -v php &> /dev/null
then
    PHP="$(php -v | grep PHP | head -n 1 | cut -d'(' -f 1)"
    PHP=${PHP:4}
    PHPVERSION=${PHP::3}
    if [[ ! $PHP == 8* ]]
    then
        OLDPHPVERSION=true
        echo ${OLDPHPVERSION}
    fi
else
    PHP='not installed'
fi

echo -e "${GREEN}PHP: ${PHP}"

if [[ $OLDPHPVERSION ]]
then
    while true; do
        echo
        echo -e "${RED}Your php version is lower than 8.0, to you want to install php version 8.0 (this is optional)?"
        echo -e "${YELLOW}Please note that if you confirm the app-repo \"ppa:ondrej/php\" will be added to your sources.${NC}"
        read -p "(y/n): " CURRENTPHPVERSION
        case $CURRENTPHPVERSION in
            [Yy]* ) 
                sudo a2dismod php${PHPVERSION}
                PHPVERSION="8.0"; 
                APTS+=( "php8.0" ); 
                add-apt-repository ppa:ondrej/php -y; break;;
            [Nn]* ) break;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
fi

if [[ ${PHP} == "not installed" ]]
then
    echo
    echo -e "${YELLOW}Since php is missing on your system, would you like to install version 8.0?" 
    echo -e "${RED}The app-repo \"ppa:ondrej/php\" must be added to your sources for this."
    echo -e "If you do not like to add an external repo, you can stay with php 7.4.${NC}"
    echo
    PS3="I would like to use option... "
    options=("8.0 from ppa:ondrej/php" "7.4 from default sources" "I don't know, please quit.")
    select opt in "${options[@]}"
    do
        case $opt in
            "8.0 from ppa:ondrej/php")
                APTS+=( "php8.0" )
                PHPVERSION="8.0"
                echo -e "${GREEN}Add app-repo \"ppa:ondrej/php\" to your sources.${NC}"
                add-apt-repository ppa:ondrej/php -y;
                break
                ;;
            "7.4 from default sources")
                APTS+=( "php7.4" )
                PHPVERSION="7.4"
                echo -e "${GREEN}Will take php7.4 from default sources.${NC}"
                break
                ;;
            "I don't know, please quit.")
                echo -e "${GREEN}Okay bye."
                exit 0
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
fi

if [[ ${APTS[*]} ]]
then
    echo
    while true; do
        echo -e "${RED}Package(s) ${APTS[*]} are missing, should I install it/them?${NC}"
        read -p "(y/n): " INSTALLPACKAGES
        case $INSTALLPACKAGES in
            [Yy]* ) apt update && apt install ${APTS[*]} -y; break;;
            [Nn]* ) echo -e "${RED}I need ${APTS[*]} to process, abort"; exit;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
else
    echo -e "${GREEN}Good, your LAMP-Stack is complete."
fi

# check if dependencies are fulfilled

echo
echo -e "${GREEN}Checking if dependencies are fulfilled..."
echo 
DEPENDENCIES=("libapache2-mod-php"\
    "php${PHPVERSION}-apcu"\
    "php${PHPVERSION}-curl"\
    "php${PHPVERSION}-gd"\
    "php${PHPVERSION}-mbstring"\
    "php${PHPVERSION}-mysql"\
    "php${PHPVERSION}-xml"
    "php${PHPVERSION}-zip")


if [[ ! $PHPVERSION == 8* ]]; then
    DEPENDENCIES+=("php${PHPVERSION}-json")
fi  


for REQUIREDPKG in "${DEPENDENCIES[@]}"
do
    if [[ "$(dpkg-query -W --showformat='${Status}\n' $REQUIREDPKG)" == "install ok installed" ]]; then
        echo -e "${GREEN}${REQUIREDPKG} is installed."
        delete=(${REQUIREDPKG})
        for target in "${delete[@]}"; do
          for i in "${!DEPENDENCIES[@]}"; do
            if [[ ${DEPENDENCIES[i]} = $target ]]; then
              unset 'DEPENDENCIES[i]'
            fi
          done
        done
    fi
done

if [[ ${DEPENDENCIES[*]} ]]
then
    echo
    while true; do
        echo -e "${RED}Package(s) ${DEPENDENCIES[*]} is/are missing, should I install it/them?${NC}"
        read -p "(y/n): " INSTALLDEPENDENCIES
        case $INSTALLDEPENDENCIES in
            [Yy]* ) apt update && apt install ${DEPENDENCIES[*]} -y; break;;
            [Nn]* ) echo -e "${RED}I need ${DEPENDENCIES[*]} to process, abort."; exit;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
else
    echo
    echo -e "${GREEN}Good, all dependencies are fulfilled."
fi

unset REQUIREDPKG
echo
echo -e "${GREEN}Checking if helpers are installed...${NC}"
echo 
HELPERS=(\
    "git" \
    "wget" \
    "unzip" \
    )

for REQUIREDPKG in "${HELPERS[@]}"; do
    if [[ "$(dpkg-query -W --showformat='${Status}\n' $REQUIREDPKG)" == "install ok installed" ]]; then
        echo -e "${GREEN}${REQUIREDPKG} is installed."
        delete=(${REQUIREDPKG})
        for target in "${delete[@]}"; do
          for i in "${!HELPERS[@]}"; do
            if [[ ${HELPERS[i]} = $target ]]; then
              unset 'HELPERS[i]'
            fi
          done
        done
    fi
done

if [[ ${HELPERS[*]} ]]
then
    printf "\n"
    while true; do
        echo -e "${RED}Helpers ${HELPERS[*]} are missing, should I install it/them?${NC}"
        read -p "(y/n): " INSTALLHELPERS
        case $INSTALLHELPERS in
            [Yy]* ) apt update && apt install ${HELPERS[*]} -y; break;;
            [Nn]* ) echo -e "${RED}I need ${HELPERS[*]} to process, abort"; exit;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
else
    echo
    echo -e "${GREEN}Good, all helpers are installed."
fi

# configure site
FINISHED=false
while [ $FINISHED == false ]
do
    echo -e "${YELLOW}What is the name of your Website (WITHOUT \"https://www.\" etc. like \"example.com\")?"
    echo -e "${YELLOW}It will be used as webroot dir at /var/www/html/ and as your servername.${NC}"
    while [[ -z $WEBSITENAME ]]
    do
        read WEBSITENAME
        if [[ -z $WEBSITENAME ]]
        then
            echo -e "${RED}Websitename can not be emtpy! Please enter a websitename!"
        fi
    done
    echo -e "${YELLOW}Enter your server admin email adress:${NC}"
    while [[ -z $SERVERADMINEMAIL ]]
    do
        read SERVERADMINEMAIL
        if [[ -z $SERVERADMINEMAIL ]]
        then
            echo -e "${RED}Server admin mail adress can not be emtpy! Please enter an amdin mail adress!"
        fi
    done
    echo -e "${GREEN}Websitename: ${WEBSITENAME}"
    echo -e "${GREEN}Server admin mail: ${SERVERADMINEMAIL}"
    echo -e "${YELLOW}Is that correct?${NC}"

    while true; do
        read -p "(y/n): " SURE
        case $SURE in
            [Yy]* )
                export WEBSITENAME;
                export SERVERADMINEMAIL;
                FINISHED=true;
                break;;
            [Nn]* )
                echo -e "${GREEN}Okay then...";
                break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
done


cp ./.remove-site ./remove_${WEBSITENAME}_configs.bash

#add websitename to hosts

if [[ $LOCALHOST ]]
then
    echo
    echo -e "${YELLOW}Since, you are on localhost, I try to add \"127.0.0.1   ${WEBSITENAME}\" to /etc/hosts."
    echo -e "Is this okay for you?${NC}"
    while true; do
        read -p "(y/n): " SURE
        case $SURE in
            [Yy]* )
                if grep -q "${WEBSITENAME}" "/etc/hosts"; then 
                    echo
                    echo -e "${RED}Entry \"127.0.0.1   ${WEBSITENAME}\" already in /etc/hosts"
                else
                    echo
                    echo -e "${YELLOW}ADD $WEBSITENAME to /etc/hosts, because you are on a localhost!"
                    echo "127.0.0.1   ${WEBSITENAME}" >> /etc/hosts
                fi
                echo "sed -i 's/127.0.0.1   ${WEBSITENAME}//g' /etc/hosts" >> ./remove_${WEBSITENAME}_configs.bash
                EDITEDHOSTS=true
                break;;
            [Nn]* )
                echo -e "${GREEN}Okay, to visit your website later on, you have to type http://localhost/${WEBSITENAME}";
                break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

# add php configuration via wisski.ini
# Tweak PHP

TWEAKPHP=$'file_uploads = On
allow_url_fopen = On
memory_limit = 256M
upload_max_filesize = 20M
max_execution_time = 60
date.timezone = Europe/Berlin
max_input_nesting_level = 640'

echo
echo -e "${YELLOW}Do you like to tweak your php?"
echo -e "${YELLOW}This will add"
echo
echo -e "${RED}${TWEAKPHP}"
echo
echo -e "${YELLOW}to"
echo 
echo -e "${RED}/etc/php/${PHPVERSION}/mods-available/wisski.ini$"
echo
echo -e "${YELLOW}and activate it.${NC}"
echo 

while true; do
    read -p "(y/n): " TWEAK
    case $TWEAK in
        [Yy]* ) 
        echo "$TWEAKPHP" > /etc/php/${PHPVERSION}/mods-available/wisski.ini
        echo -e "${GREEN}Activate wisski.ini.${NC}"
        phpenmod -v ${PHPVERSION} wisski
        echo "phpdismod -v ${PHPVERSION} wisski"  >> ./remove_${WEBSITENAME}_configs.bash
        echo "rm /etc/php/${PHPVERSION}/mods-available/wisski.ini" >> ./remove_${WEBSITENAME}_configs.bash
        break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# enable mod-rewrite 
echo
echo -e "${GREEN}Enable mod_rewrite for apache2.${NC}"
echo 
a2enmod rewrite &> /dev/null

# restart apache
echo
echo -e "${GREEN}Restart apache server${NC}"
systemctl restart apache2 &> /dev/null
echo


echo
echo -e "${YELLOW}Do you like to add your site to your apache config?"
echo -e "This will create \"/etc/apache2/sites-available/${WEBSITENAME}.conf\".${NC}"

SITECONFIG=$'<VirtualHost *:80>
    ServerAdmin ${SERVERADMINEMAIL}
    DocumentRoot \"/var/www/html/${WEBSITENAME}/web\"
    ServerName www.${WEBSITENAME}
    ServerAlias ${WEBSITENAME}
    ErrorLog \"/var/log/apache2/${WEBSITENAME}-error_log\"
    CustomLog \"/var/log/apache2/${WEBSITENAME}-access_log\" common
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
</VirtualHost>'

while true; do
    read -p "(y/n): " WRITECONFIG
    case $WRITECONFIG in
        [Yy]* ) 
            echo -e "${GREEN}Write config to \"/etc/apache2/sites-available/${WEBSITENAME}\""
            echo "$SITECONFIG" > /etc/apache2/sites-available/${WEBSITENAME}.conf
            echo -e "${GREEN}Enable site ${WEBSITENAME}${NC}"
            a2ensite ${WEBSITENAME}
            echo -e "${GREEN}Restart apache server${NC}"
            systemctl restart apache2
            echo "a2dissite ${WEBSITENAME}"  >> ./remove_${WEBSITENAME}_configs.bash
            echo "rm /etc/apache2/sites-available/${WEBSITENAME}.conf;" >> ./remove_${WEBSITENAME}_configs.bash
            break;;
        [Nn]* ) 
            break;;
        * ) echo "Please answer y[es] or n[o].";;
    esac
done

# only if mariadb was not installed
# run mariadb security script

if [[ ${MYSQL} == "not installed" ]]
then
    echo -e "${YELLOW}Seems you have a fresh install of MariaDB"
    echo -e "Do you want to secure Mariadb?${NC}"
    while true; do
        read -p "(y/n): " SECUREMARIADB
        case $SECUREMARIADB in
            [Yy]* ) 
                echo -e "${GREEN}Please note your credentials!";
                mysql_secure_installation;
                break;;
            [Nn]* ) 
                break;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
fi

# create database user and database 
echo
echo -e "${YELLOW}Create database and user for Drupal. Please note your inputs, they will be needed in a moment."
CORRECTDATABASE=false 
CORRECTUSER=false
FINISHED=false
while [[ $CORRECTDATABASE == false ]] && [[ $CORRECTUSER == false ]]; do
    while [[ $FINISHED == false ]]; do
        echo -e "${YELLOW}Enter name of the Database, you want to create:${NC}"
        read DB
        if [[ ! -z "`mysql -qfsBe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB}'" 2>&1`" ]]; then
            echo
            echo -e "${RED}Database already exists!"
            echo -e "Should I drop it and recreate? Attention: All data will be lost and can not be recovered!${NC}"
            while true; do
                read -p "(recreate/keep/rename/abort): " SURE
                case $SURE in
                    [recreate]* ) 
                        mysql -e "DROP DATABASE ${DB};"
                        mysql -e "CREATE DATABASE ${DB} ;"
                        echo -e "${GREEN}Recreated database ${DB}."
                        FINISHED=true
                        break;;
                    [keep]* ) 
                        echo -e "${GREEN}Okay keep old database..."
                        FINISHED=true
                        break;;
                    [retry]* )
                        echo -e "${GREEN}Okay, then..."
                        break;;
                    [abort]* )
                        echo -e "${GREEN}Okay, bye"
                        exit;;
                    * ) echo "Please answer y[es], n[o], rename or abort!";;
                esac
            done
        else
            mysql -e "CREATE DATABASE ${DB} ;"
            echo -e "${GREEN}Created database ${DB}."
            FINISHED=true
            CORRECTDATABASE=true
        fi
    done
    FINISHED=false
    while [[ $FINISHED == false ]]; do
        echo
        echo -e "${YELLOW}Enter name of the user you want to create:${NC}"
        read USER
        echo -e "${YELLOW}Enter passwort of that user:${NC}"
        read USERPW
        echo
        echo -e "${GREEN}Database username: ${USER}"
        echo -e "Database user password: ${USERPW}"
        echo -e "${YELLOW}Is that correct?${NC}"
        while true; do
            read -p "(y/n): " SURE
            case $SURE in
                [Yy]* ) 
                if [[ ! -z "`mysql -qfsBe "SELECT User FROM mysql.user WHERE User = '${USER}'" 2>&1`" ]];
                then
                    echo
                    echo -e "${RED}User already exists!"
                    echo -e "Should I drop it and recreate or keep existing user?${NC}"
                    while true; do
                        read -p "(recreate/keep): " SURE
                        case $SURE in
                            [recreate]* ) 
                                mysql -e "DROP USER ${DB}@'localhost';"
                                mysql -e "CREATE USER ${DB}@localhost IDENTIFIED BY '${USERPW}';"
                                mysql -e "GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';"
                                mysql -e "FLUSH PRIVILEGES;"
                                echo -e "${GREEN}Recreated User ${USER}."
                                FINISHED=true
                                CORRECTUSER=true
                                break;;
                            [keep]* ) 
                                unset USERPW
                                echo
                                echo -e "${GREEN}Okay keep existing user."
                                while [[ -z ${USERPW} ]]; do
                                    echo -e "${YELLOW}What is the password of this user?"
                                    echo -e "${RED}Be sure that the password is correct!${NC}"
                                    read USERPW
                                    while true; do
                                        echo
                                        echo -e "${GREEN}User password is: ${USERPW}"
                                        echo -e "${YELLOW}Is this correct?${NC}"
                                        read -p "(y/n): " SURE
                                        case $SURE in
                                            [Yy]* ) 
                                                CORRECTUSER=true
                                                break;;
                                            [Nn]* ) 
                                                unset USERPW
                                                break;;
                                            [abort]* )
                                                echo -e "${GREEN}Okay, bye"
                                                exit;;
                                            * ) echo "Please answer y[es], n[o] or abort!";;
                                        esac
                                    done
                                done
                                FINISHED=true
                                break;;
                            * ) echo "Please answer y[es] or keep.";;
                        esac
                    done
                else
                    mysql -e "CREATE USER ${DB}@localhost IDENTIFIED BY '${USERPW}';"
                    mysql -e "GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';"
                    mysql -e "FLUSH PRIVILEGES;"
                    echo
                    echo -e "${GREEN}Created User ${USER}."
                    FINISHED=true
                    CORRECTUSER=true
                fi
                    break;;
                [Nn]* ) 
                    echo -e "${GREEN}Okay then..."
                    break;;
                * ) echo -e "${RED}Please answer y[es] or n[o].";;
            esac
        done
    done    
done

echo
echo -e "${GREEN}Created ${DB} database with ${USER}@localhost identified by ${USERPW}."
sleep 1

# install drupal with drush
echo
echo -e "${GREEN}You are ready to install Drupal! It will be installed under /var/www/html/$WEBSITENAME."
echo -e "${YELLOW}Should I start?${NC}"
while true; do
    read -p "(y/n): " INSTALLDRUPAL
    case $INSTALLDRUPAL in
        [Yy]* ) 
            echo -e "${GREEN}Okay, I will start installation!"
            break;;
        [Nn]* )
            echo -e "${GREEN}Okay bye." 
            exit;;
        * ) echo "Please answer y[es] or n[o].";;
    esac
done



cd /var/www/html/

if ! command -v composer &> /dev/null
then
    echo
    echo -e "${RED}Seems that composer is not installed, do you like to install it?${NC}"
    while true; do
        read -p "(y/n): " INSTALLCOMPOSER
        case ${INSTALLCOMPOSER} in
            [Yy]* )
                echo -e "${RED}I will install composer at \"/usr/local/bin/composer\"${NC}"
                php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
                php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
                php composer-setup.php --filename=composer --install-dir=/usr/local/bin
                php -r "unlink('composer-setup.php');"
                break;;
            [Nn]* ) break;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done
fi

echo
echo -e "${RED}Composer will scold you for being root, do not worry, we take care of this later - answer always \"y\".${NC}"
echo
composer create-project drupal/recommended-project $WEBSITENAME
chown -R www-data:www-data $WEBSITENAME
chmod 775 -R $WEBSITENAME

echo
echo -e "${GREEN}Installing WissKI with some modules (you have to activate them later).${NC}"
echo
cd /var/www/html/$WEBSITENAME
composer require drupal/colorbox drupal/devel drush/drush drupal/imagemagick 'drupal/inline_entity_form:1.x-dev@dev' 'drupal/wisski:^3.0@RC'
cd web/modules/contrib/wisski

echo
echo -e "${GREEN}Autoload WissKI dependencies.${NC}"
echo
composer update
cd /var/www/html/$WEBSITENAME


echo
echo -e "${YELLOW}Do you like to get colorbox and mirador libraries?${NC}"
echo

while true; do
        read -p "(y/n): " INSTALLCOMPOSER
        case ${INSTALLCOMPOSER} in
            [Yy]* )
                mkdir -p web/libraries
                ## get colorbox
                wget https://github.com/jackmoore/colorbox/archive/refs/heads/master.zip -P web/libraries/
                unzip web/libraries/master.zip -d web/libraries/
                mv web/libraries/colorbox-master web/libraries/colorbox
                ## get mirador
                wget http://wisskieu.nasarek.org/sites/default/files/assets/mirador.zip -P web/libraries/
                unzip web/libraries/mirador.zip -d web/libraries/
                break;;
            [Nn]* )
                echo -e "${GREEN}Okay, you can download it later from:"
                echo -e "https://github.com/jackmoore/colorbox/archive/refs/heads/master.zip"
                echo -e "and"
                echo -e "http://wisskieu.nasarek.org/sites/default/files/assets/mirador.zip${NC}"
                break;;
            * ) echo "Please answer y[es] or n[o].";;
        esac
    done

#echo change permissions for webroot to www-data

echo
echo -e "${GREEN}Change permissions to www-data at \"/var/www/html/$WEBSITENAME\".${NC}"
echo
chown -R www-data:www-data ../$WEBSITENAME
chmod 775 -R ../$WEBSITENAME

if [[ ! ${LOCALHOST} ]]; then
    echo
    echo -e "${YELLOW}You are installing WissKI for production, do you like to add https support?" 
    echo -e "You can use certbot and letsencrypt for an automaticaly installation and configuration"
    echo -e "of all certificates and Apache config files or"
    echo -e "use your own certificates and configure Apache manually.${NC}"
    echo

    PS3="I would like to... "
    options=("use certbots automode." "configure Apache manually." "I don't know, please skip this.")
    select opt in "${options[@]}"
    do
        case $opt in
            "use certbots automode.")
                echo -e "${GREEN}Okay, installing certbot which obtaining letsencrypt certificates!"
                echo -e "Please note, that you need a correct DNS configuration with"
                echo -e "${WEBSITENAME} or www.${WEBSITENAME} pointing with a \"A\" record to your ServerIP"
                echo -e "${YELLOW}Can we start?${NC}"
                while true; do
                    read -p "(y/n): " INSTALLCERTBOT
                    case $INSTALLCERTBOT in
                        [Yy]* )
                            apt remove certbot -y
                            snap install core
                            snap refresh core
                            snap install --classic certbot
                            ln -s /snap/bin/certbot /usr/bin/certbot
                            sudo certbot --apache
                            break;;
                        [Nn]* ) 
                            echo -e "${GREEN}Okay skipping.";
                            for (( i=0; i<${#options[@]}; i++)); do
                                printf '%d) %s\n' $((i+1)) "${options[$i]}"
                            done
                            continue 2;;
                        * ) echo "Please answer y[es] or n[o].";;
                    esac
                done;
                break
                ;;
            "configure Apache manually.")
                echo
                echo -e "${GREEN}You can use \"example-ssl.conf\" as a template. Please alter <your email>,"
                echo -e "<your website>, the paths to your certificate files and rewrite rules."
                echo -e "Copy it to /etc/apache2/sites-available/${WEBSITENAME}-ssl.conf"
                echo -e "and enable it with \"sudo a2ensite ${WEBSITENAME}-ssl\""
                break
                ;;
            "I don't know, please skip this.")
                echo -e "${GREEN}Okay skipping.${NC}"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
fi

echo
if [[ ${EDITEDHOSTS} ]]; then
    echo -e "${GREEN}Thats it! You can now visit http://${WEBSITENAME} or and install Drupal!${NC}"
else
    echo -e "${GREEN}Thats it! You can now visit http://localhost/${WEBSITENAME} or and install Drupal!${NC}"
fi
exit 0