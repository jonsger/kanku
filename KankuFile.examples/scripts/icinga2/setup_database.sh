#!/bin/bash

################################################################################
# SETTINGS
################################################################################

ICINGA2_DB_NAME=icinga
ICINGA2_DB_USER=icinga
ICINGA2_DB_PASS=icinga

ICINGAWEB2_DB_NAME=icingaweb2
ICINGAWEB2_DB_USER=icingaweb2
ICINGAWEB2_DB_PASS=icingaweb2
ICINGAWEB2_DB_RES=icingaweb2

ICINGAWEB2_ADMIN_USER=admin
ICINGAWEB2_ADMIN_GROUP=admin
ICINGAWEB2_ADMIN_PASS=opensuse


################################################################################
# MAIN
################################################################################
mysql -e "create database $ICINGA2_DB_NAME"
mysql -e "CREATE USER '$ICINGA2_DB_USER'@'localhost' IDENTIFIED BY '$ICINGA2_DB_PASS'"
mysql -e "GRANT ALL PRIVILEGES ON $ICINGA2_DB_NAME.* TO '$ICINGA2_DB_USER'@'localhost'"

mysql $ICINGA2_DB_NAME < /usr/share/icinga2-ido-mysql/schema/mysql.sql

icinga2 feature enable ido-mysql
icinga2 feature enable command
#icinga2 feature enable api
systemctl restart icinga2

mysql -e "create database $ICINGAWEB2_DB_NAME"
mysql -e "CREATE USER '$ICINGAWEB2_DB_USER'@'localhost' IDENTIFIED BY '$ICINGAWEB2_DB_PASS'"
mysql -e "GRANT ALL PRIVILEGES ON $ICINGAWEB2_DB_NAME.* TO '$ICINGAWEB2_DB_USER'@'localhost'"
mysql -D icingaweb2 < /usr/share/doc/icingaweb2/schema/mysql.schema.sql
PWHASH=`openssl passwd -1 $ICINGAWEB2_ADMIN_PASS`
mysql -e "INSERT INTO icingaweb_user (name, active, password_hash) VALUES ('$ICINGAWEB2_ADMIN_USER', 1, '$PWHASH')" $ICINGAWEB2_DB_NAME

icingacli setup config webserver apache > /etc/apache2/vhosts.d/icingaweb2.conf

# FIXME: clarify if needed on opensuse
icingacli setup config directory

cat <<EOF > /etc/icingaweb2/resources.ini
[$ICINGAWEB2_DB_RES]
type                = "db"
db                  = "mysql"
host                = "localhost"
port                = "3306"
dbname              = $ICINGAWEB2_DB_NAME
username            = $ICINGAWEB2_DB_USER
password            = $ICINGAWEB2_DB_PASS


[icinga2]
type                = "db"
db                  = "mysql"
host                = "localhost"
port                = "3306"
dbname              = $ICINGA2_DB_NAME
username            = $ICINGA2_DB_USER
password            = $ICINGA2_DB_PASS
EOF

cat <<EOF > /etc/icingaweb2/authentication.ini
[auth_db]
backend  = db
resource = $ICINGAWEB2_DB_RES
EOF

cat <<EOF > /etc/icingaweb2/groups.ini
[icingaweb2]
backend = "db"
resource = $ICINGAWEB2_DB_RES
EOF

cat <<EOF > /etc/icingaweb2/roles.ini
[admin]
users="$ICINGAWEB2_ADMIN_USER"
groups="$ICINGAWEB2_ADMIN_GROUP"
permissions="*"
monitoring/filter/objects = "*"
EOF

usermod -a -G icingaweb2 wwwrun


exit 0
