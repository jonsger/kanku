#!/bin/bash

DB_NAME=icinga2
DB_USER=icinga2
DB_PASS=icinga2

influx <<EOF
create database $DB_NAME;
create user $DB_USER with password '$DB_PASS';
grant all on $DB_NAME to $DB_USER;
EOF

