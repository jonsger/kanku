#!/bin/bash

zypper -n in pwgen

MYSQL_ROOT_PWD=`pwgen -1`

mysqladmin password $MYSQL_ROOT_PWD
echo -en "[client]\npassword=$MYSQL_ROOT_PWD\n" > /root/.my.cnf

mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -e "FLUSH PRIVILEGES;"

exit 0;
