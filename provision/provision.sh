#!/bin/bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations included with Varying Vagrant Vagrants.

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

# Capture a basic ping result to Google's primary DNS server to determine if
# outside access is available to us. If this does not reply after 2 attempts,
# we try one of Level3's DNS servers as well. If neither IP replies to a ping,
# then we'll skip a few things further in provisioning rather than creating a
# bunch of errors.
ping_result="$(ping -c 2 8.8.4.4 2>&1)"
if [[ $ping_result != *bytes?from* ]]; then
	ping_result="$(ping -c 2 4.2.2.2 2>&1)"
fi

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.
apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(

	# PHP7
    php7.0-fpm
    php7.0-cli
    php7.0-common
    php7.0-json
    php7.0-opcache
    php7.0-mysql
    php7.0-phpdbg
    php7.0-mbstring
    php7.0-gd
    php-imagick
    php7.0-pgsql
    php7.0-pspell
    php7.0-recode
    php7.0-tidy
    php7.0-dev
    php7.0-intl
    php7.0-gd
    php7.0-curl
    php7.0-zip
    php7.0-xml
    php-memcached
    mcrypt
    phpunit

	# nginx is installed as the default web server
	nginx

	# memcached is made available for object caching
	memcached

	# mysql is the default database
	mysql-server

	# other packages that come in handy
	imagemagick
	subversion
	git-core
	zip
	unzip
	ngrep
	curl
	make
	vim
	colordiff
	postfix

	# Req'd for i18n tools
	gettext

	# Req'd for Webgrind
	graphviz

	# dos2unix
	# Allows conversion of DOS style line endings to something we'll have less
	# trouble with in Linux.
	dos2unix

	# nodejs for use by grunt
	g++
	npm
	nodejs

	# addtional #
    htop
    mc
)
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get -y update

echo "Check for apt packages to install..."

# Loop through each of our packages that should be installed on the system. If
# not yet installed, it should be added to the array of packages to install.
for pkg in "${apt_package_check_list[@]}"; do
	package_version="$(dpkg -s $pkg 2>&1 | grep 'Version:' | cut -d " " -f 2)"
	if [[ -n "${package_version}" ]]; then
		space_count="$(expr 20 - "${#pkg}")" #11
		pack_space_count="$(expr 30 - "${#package_version}")"
		real_space="$(expr ${space_count} + ${pack_space_count} + ${#package_version})"
		printf " * $pkg %${real_space}.${#package_version}s ${package_version}\n"
	else
		echo " *" $pkg [not installed]
		apt_package_install_list+=($pkg)
	fi
done

# There is a naming conflict with the node package (Amateur Packet Radio Node
# Program), and the nodejs binary has been renamed from node to nodejs. We need
# to symlink to put it back.
ln -s /usr/bin/nodejs /usr/bin/node

# MySQL
#
# Use debconf-set-selections to specify the default password for the root MySQL
# account. This runs on every provision, even if MySQL has been installed. If
# MySQL is already installed, it will not affect anything.
echo mysql-server mysql-server/root_password password root | debconf-set-selections
echo mysql-server mysql-server/root_password_again password root | debconf-set-selections

# Postfix
#
# Use debconf-set-selections to specify the selections in the postfix setup. Set
# up as an 'Internet Site' with the host name 'vvv'. Note that if your current
# Internet connection does not allow communication over port 25, you will not be
# able to send mail, even with postfix installed.
echo postfix postfix/main_mailer_type select Internet Site | debconf-set-selections
echo postfix postfix/mailname string vvv | debconf-set-selections


if [[ $ping_result == *bytes?from* ]]; then
	# If there are any packages to be installed in the apt_package_list array,
	# then we'll run `apt-get update` and then `apt-get install` to proceed.
	if [[ ${#apt_package_install_list[@]} = 0 ]]; then
		echo -e "No apt packages to install.\n"
	else
		# Before running `apt-get update`, we should add the public keys for
		# the packages that we are installing from non standard sources via
		# our appended apt source.list

		# Nginx.org nginx key ABF5BD827BD9BF62
		gpg -q --keyserver keyserver.ubuntu.com --recv-key ABF5BD827BD9BF62
		gpg -q -a --export ABF5BD827BD9BF62 | apt-key add -

		# update all of the package references before installing anything
		echo "Running apt-get update..."
		apt-get update --assume-yes

		# install required packages
		echo "Installing apt-get packages..."
		apt-get install --assume-yes ${apt_package_install_list[@]}

		# Clean up apt caches
		apt-get clean
	fi

	# ack-grep
	#
	# Install ack-rep directory from the version hosted at beyondgrep.com as the
	# PPAs for Ubuntu Precise are not available yet.
	if [[ -f /usr/bin/ack ]]; then
		echo "ack-grep already installed"
	else
		echo "Installing ack-grep as ack"
		curl -s http://beyondgrep.com/ack-2.04-single-file > /usr/bin/ack && chmod +x /usr/bin/ack
	fi

	# COMPOSER
	#
	# Install or Update Composer based on current state. Updates are direct from
	# master branch on GitHub repository.
	if [[ -n "$(composer --version | grep -q 'Composer version')" ]]; then
		echo "Updating Composer..."
		COMPOSER_HOME=/usr/local/src/composer composer self-update
		COMPOSER_HOME=/usr/local/src/composer composer global update
	else
		echo "Installing Composer..."
		curl -sS https://getcomposer.org/installer | php
		chmod +x composer.phar
		mv composer.phar /usr/local/bin/composer

		COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update phpunit/phpunit:4.0.*
		COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update phpunit/php-invoker:1.1.*
		COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update mockery/mockery:0.8.*
		COMPOSER_HOME=/usr/local/src/composer composer -q global require --no-update d11wtq/boris:v1.0.2
		COMPOSER_HOME=/usr/local/src/composer composer -q global config bin-dir /usr/local/bin
		COMPOSER_HOME=/usr/local/src/composer composer global update
	fi

	# Grunt
	#
	# Install or Update Grunt based on current state.  Updates are direct
	# from NPM
	if [[ "$(grunt --version)" ]]; then
		echo "Updating Grunt CLI"
		npm update -g grunt-cli &>/dev/null
		npm update -g grunt-sass &>/dev/null
		npm update -g grunt-cssjanus &>/dev/null
	else
		echo "Installing Grunt CLI"
		npm install -g grunt-cli &>/dev/null
		npm install -g grunt-sass &>/dev/null
		npm install -g grunt-cssjanus &>/dev/null
	fi
else
	echo -e "\nNo network connection available, skipping package installation"
fi

# Configuration for nginx
if [[ ! -e /etc/nginx/server.key ]]; then
	echo "Generate Nginx server private key..."
	vvvgenrsa="$(openssl genrsa -out /etc/nginx/server.key 2048 2>&1)"
	echo $vvvgenrsa
fi
if [[ ! -e /etc/nginx/server.csr ]]; then
	echo "Generate Certificate Signing Request (CSR)..."
	openssl req -new -batch -key /etc/nginx/server.key -out /etc/nginx/server.csr
fi
if [[ ! -e /etc/nginx/server.crt ]]; then
	echo "Sign the certificate using the above private key and CSR..."
	vvvsigncert="$(openssl x509 -req -days 365 -in /etc/nginx/server.csr -signkey /etc/nginx/server.key -out /etc/nginx/server.crt 2>&1)"
	echo $vvvsigncert
fi

echo -e "\nSetup configuration files..."

# Used to to ensure proper services are started on `vagrant up`
cp /srv/config/init/vvv-start.conf /etc/init/vvv-start.conf

echo " * /srv/config/init/vvv-start.conf               -> /etc/init/vvv-start.conf"

# Copy nginx configuration from local
cp /srv/config/nginx-config/nginx.conf /etc/nginx/nginx.conf
if [[ ! -d /etc/nginx/custom-sites ]]; then
	mkdir /etc/nginx/custom-sites/
fi
rsync -rvzh --delete /srv/config/nginx-config/sites/ /etc/nginx/custom-sites/

echo " * /srv/config/nginx-config/nginx.conf           -> /etc/nginx/nginx.conf"
echo " * /srv/config/nginx-config/sites/               -> /etc/nginx/custom-sites"

#
# PHP Errors
#
echo -e "----------------------------------------"
echo "VAGRANT ==> Setup PHP 7"
sudo sed -i 's/short_open_tag = Off/short_open_tag = On/' /etc/php/7.0/fpm/php.ini
sudo sed -i 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/' /etc/php/7.0/fpm/php.ini
sudo sed -i 's/display_startup_errors = Off/display_startup_errors = On/' /etc/php/7.0/fpm/php.ini
sudo sed -i 's/display_errors = Off/display_errors = On/' /etc/php/7.0/fpm/php.ini

# Copy memcached configuration from local
cp /srv/config/memcached-config/memcached.conf /etc/memcached.conf

echo " * /srv/config/memcached-config/memcached.conf   -> /etc/memcached.conf"

# Copy custom dotfiles and bin file for the vagrant user from local
cp /srv/config/bash_profile /home/vagrant/.bash_profile
cp /srv/config/bash_aliases /home/vagrant/.bash_aliases
cp /srv/config/vimrc /home/vagrant/.vimrc
if [[ ! -d /home/vagrant/.subversion ]]; then
	mkdir /home/vagrant/.subversion
fi
cp /srv/config/subversion-servers /home/vagrant/.subversion/servers
if [[ ! -d /home/vagrant/bin ]]; then
	mkdir /home/vagrant/bin
fi
rsync -rvzh --delete /srv/config/homebin/ /home/vagrant/bin/

echo " * /srv/config/bash_profile                      -> /home/vagrant/.bash_profile"
echo " * /srv/config/bash_aliases                      -> /home/vagrant/.bash_aliases"
echo " * /srv/config/vimrc                             -> /home/vagrant/.vimrc"
echo " * /srv/config/subversion-servers                -> /home/vagrant/.subversion/servers"
echo " * /srv/config/homebin                           -> /home/vagrant/bin"

#
# redis
#
echo -e "----------------------------------------"
echo "VAGRANT ==> Redis Server"
apt-get install -y redis-server redis-tools
cp /etc/redis/redis.conf /etc/redis/redis.bkup.conf
sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf


echo -e "----------------------------------------"
echo "VAGRANT ==> PHP Redis"
git clone https://github.com/phpredis/phpredis.git
cd phpredis
git checkout php7
phpize
./configure
make && make install
cd ..
rm -rf phpredis
cd ~/
echo "extension=redis.so" > ~/redis.ini
cp ~/redis.ini /etc/php/7.0/mods-available/redis.ini
ln -s /etc/php/7.0/mods-available/redis.ini /etc/php/7.0/fpm/conf.d/20-redis.ini

echo -e "----------------------------------------"
echo "VAGRANT ==> Restart Redis & PHP"
service redis-server restart

#
# Phalcon PHP Framework 3
#
echo -e "----------------------------------------"
echo "VAGRANT ==> Setup Phalcon Framework 3"
cd ~/
sudo apt-add-repository ppa:phalcon/stable
sudo apt-get update
sudo apt-get install -y php7.0-phalcon
echo 'extension=phalcon.so' > /etc/php/7.0/mods-available/phalcon.ini
ln -s /etc/php/7.0/mods-available/phalcon.ini /etc/php/7.0/fpm/conf.d/20-phalcon.ini

# RESTART SERVICES
#
# Make sure the services we expect to be running are running.
echo -e "\nRestart services..."
service nginx restart
service memcached restart
service php7.0-fpm restart

# If MySQL is installed, go through the various imports and service tasks.
exists_mysql="$(service mysql status)"
if [[ "mysql: unrecognized service" != "${exists_mysql}" ]]; then
	echo -e "\nSetup MySQL configuration file links..."

	# Copy mysql configuration from local
	cp /srv/config/mysql-config/my.cnf /etc/mysql/my.cnf
	cp /srv/config/mysql-config/root-my.cnf /home/vagrant/.my.cnf

	echo " * /srv/config/mysql-config/my.cnf               -> /etc/mysql/my.cnf"
	echo " * /srv/config/mysql-config/root-my.cnf          -> /home/vagrant/.my.cnf"

	# MySQL gives us an error if we restart a non running service, which
	# happens after a `vagrant halt`. Check to see if it's running before
	# deciding whether to start or restart.
	if [[ "mysql stop/waiting" == "${exists_mysql}" ]]; then
		echo "service mysql start"
		service mysql start
	else
		echo "service mysql restart"
		service mysql restart
	fi

	# IMPORT SQL
	#
	# Create the databases (unique to system) that will be imported with
	# the mysqldump files located in database/backups/
	if [[ -f /srv/database/init-custom.sql ]]; then
		mysql -u root -proot < /srv/database/init-custom.sql
		echo -e "\nInitial custom MySQL scripting..."
	else
		echo -e "\nNo custom MySQL scripting found in database/init-custom.sql, skipping..."
	fi

	# Setup MySQL by importing an init file that creates necessary
	# users and databases that our vagrant setup relies on.
	mysql -u root -proot < /srv/database/init.sql
	echo "Initial MySQL prep..."

else
	echo -e "\nMySQL is not installed. No databases imported."
fi

if [[ $ping_result == *bytes?from* ]]; then

	# Download and extract phpMemcachedAdmin to provide a dashboard view and
	# admin interface to the goings on of memcached when running
	if [[ ! -d /srv/www/tools/web/memcached-admin ]]; then
		echo -e "\nInstalling phpMemcachedAdmin from git"
		cd /srv/www/tools/web
        git clone https://github.com/elijaa/phpmemcachedadmin.git memcached-admin
	else
		echo -e "\nUpdating phpMemcachedAdmin"
        cd /srv/www/tools/web/memcached-admin
		git pull --rebase origin master
	fi

	# Checkout Opcache Status to provide a dashboard for viewing statistics
	# about PHP's built in opcache.
	if [[ ! -d /srv/www/tools/web/opcache-status ]]; then
		echo -e "\nDownloading Opcache Status, see https://github.com/rlerdorf/opcache-status/"
		cd /srv/www/tools/web
		git clone https://github.com/rlerdorf/opcache-status.git opcache-status
	else
		echo -e "\nUpdating Opcache Status"
		cd /srv/www/tools/web/opcache-status
		git pull --rebase origin master
	fi
    
	# Download phpMyAdmin
	if [[ ! -d /srv/www/tools/web/database-admin ]]; then
		echo "Downloading phpMyAdmin 4.1.14..."
		cd /srv/www/tools/web
		#wget -q -O phpmyadmin.tar.gz 'https://files.phpmyadmin.net/phpMyAdmin/4.1.14/phpMyAdmin-4.1.14-all-languages.tar.gz'
        wget -q -O phpmyadmin.tar.gz 'https://files.phpmyadmin.net/phpMyAdmin/4.7.6/phpMyAdmin-4.7.6-all-languages.tar.gz'
		tar -xf phpmyadmin.tar.gz
		mv phpMyAdmin-4.7.6-all-languages database-admin
		rm phpmyadmin.tar.gz
	else
		echo "PHPMyAdmin already installed."
	fi
	cp /srv/config/phpmyadmin-config/config.inc.php /srv/www/tools/web/database-admin/
else
	echo -e "\nNo network available, skipping network installations"
fi

# RESTART SERVICES AGAIN
#
# Make sure the services we expect to be running are running.
echo -e "\nRestart Nginx..."
service nginx restart

end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Provisioning complete in "$(expr $end_seconds - $start_seconds)" seconds"
if [[ $ping_result == *bytes?from* ]]; then
	echo "External network connection established, packages up to date."
else
	echo "No external network available. Package installation and maintenance skipped."
fi
#echo "For further setup instructions, visit http://vvv.dev"

echo
echo ------------ FINISHED -----------------
echo Put the following lines to your host file and access http://test.dev:
echo $vvv_ip tools.dev
echo "file (unix systems): /etc/hosts"
echo "file (win): %SystemRoot%\system32\drivers\etc\hosts"
echo
echo Connect with MySQl Client by:
echo host: 192.186.50.5
echo user: local
echo pass: local
