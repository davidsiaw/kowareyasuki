mysqld -u root &
sleep 4
mysql -u root < /initfile
sleep 4
killall mysqld
chown mysql:mysql /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld
