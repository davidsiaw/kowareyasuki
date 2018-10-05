cd /tmp
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/repo-codename select xenial'
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/repo-distro select ubuntu'
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/repo-url string http://repo.mysql.com/apt/'
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-preview select '
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-product select Ok'
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-server select mysql-5.7'
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-tools select '
debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/unsupported-platform select abort'

{ \
	echo mysql-5.7 mysql-community-server/data-dir select ''; \
	echo mysql-5.7 mysql-community-server/root-pass password ''; \
	echo mysql-5.7 mysql-community-server/re-root-pass password ''; \
	echo mysql-5.7 mysql-community-server/remove-test-db select false; \
} | debconf-set-selections

{ \
	echo mysql-community-server mysql-community-server/data-dir select ''; \
	echo mysql-community-server mysql-community-server/root-pass password ''; \
	echo mysql-community-server mysql-community-server/re-root-pass password ''; \
	echo mysql-community-server mysql-community-server/remove-test-db select false; \
} | debconf-set-selections

wget https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
dpkg -i mysql-apt-config_*.deb
apt-get update -y
DEBIAN_PRIORITY=critical apt-get install -y mysql-server

sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
mkdir -p /var/run/mysqld
mkdir -p /var/lib/mysql

chown -R mysql:mysql /var/run/mysqld
chown -R mysql:mysql /var/lib/mysql
