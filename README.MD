# INSTALL WISSKI SCRIPT
This script installs a LAMP-Stack (Apache2, PHP, Mariadb) or complete missing parts on your Ubuntu 20.04 (or higher) and everything you need to start an install of the latest Drupal version (composer and drush). You can choose between a local development or production environment and you have the possibility to activate ssl support (manually or with certbot). WissKI and all necessary modules/ libraries could be downloaded. Just run the Drupal installer after the script has finished and activate required WissKI modules. Please keep in mind that WissKI needs a triple store to work.
## Usage
Just run `sudo ./install_wisski.bash` in your console.
## What it does
### LAMP-Stack
It searches for installed LAMP-Stack components and helps to install missing parts.
It's cool with MySQL as well as MariaDB but if none of those DBMS is installed, it asks you to install MariaDB. 
You must install PHP7.4 or higher, sorry.
### Configs
You have the possibility to tweak your php environment and create a virtual host entry for the Apache server.
### Database
The scripts helps you secure a fresh DBMS installation and create (or keep) your database and database users.
### Drupal
Drupal is installed via composers recommended-project option (where vendor and web directory is seperated).
The script also download WissKI-parts, and dependencies respectively libraries. The installation of the colorbox is quite straightforward. Just some small download. The mirador library is a precompiled zip ready to use and it comes with an IIP Server, so this part is quite intense. The IIPImage server can be reached at http://localhost/iipsrv/iipsrv.fcgi after the installation (important for the WissKI IIIF config. Since colorbox is widely used, Mirador is more special, so skip mirador if you do not need it. 
### SSL
If you choose to install in production mode, you have the possibility to enable ssl support. 
Either you have already certificates, than you can adapt the `example-ssl.conf` or you use certbot to get some from letsencrypt.
## More
More information and other installation options at [WissKI-Website](wisskieu.nasarek.org)
