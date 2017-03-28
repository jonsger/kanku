#!/bin/bash

client=$1

if [ -z "$client" ];then
  echo "Usage: "`basename $0`" <client_hostname>"
  exit 1
fi

mkdir /etc/rabbitmq/$client
cd /etc/rabbitmq/$client
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -out req.pem -outform PEM -subj /CN=$client/O=client/ -nodes
cd /etc/rabbitmq/testca
openssl ca -config /etc/rabbitmq/testca/openssl.cnf -in /etc/rabbitmq/$client/req.pem -out /etc/rabbitmq/$client/cert.pem -notext -batch -extensions client_ca_extensions

exit 1
