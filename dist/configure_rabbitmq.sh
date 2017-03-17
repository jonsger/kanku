#!/bin/bash

rcrabbitmq-server stop

FQHN=$(hostname -f)

cd /etc/rabbitmq/
mkdir testca
cd testca
mkdir certs private
chmod 700 private
echo 01 > serial
touch index.txt
cat <<EOF > openssl.cnf

[ ca ]
default_ca = testca

[ testca ]
dir = .
certificate = \$dir/cacert.pem
database = \$dir/index.txt
new_certs_dir = \$dir/certs
private_key = \$dir/private/cakey.pem
serial = \$dir/serial

default_crl_days = 7
default_days = 365
default_md = sha256

policy = testca_policy
x509_extensions = certificate_extensions

[ testca_policy ]
commonName = supplied
stateOrProvinceName = optional
countryName = optional
emailAddress = optional
organizationName = optional
organizationalUnitName = optional
domainComponent = optional

[ certificate_extensions ]
basicConstraints = CA:false

[ req ]
default_bits = 2048
default_keyfile = ./private/cakey.pem
default_md = sha256
prompt = yes
distinguished_name = root_ca_distinguished_name
x509_extensions = root_ca_extensions

[ root_ca_distinguished_name ]
commonName = hostname

[ root_ca_extensions ]
basicConstraints = CA:true
keyUsage = keyCertSign, cRLSign

[ client_ca_extensions ]
basicConstraints = CA:false
keyUsage = digitalSignature
extendedKeyUsage = 1.3.6.1.5.5.7.3.2

[ server_ca_extensions ]
basicConstraints = CA:false
keyUsage = keyEncipherment
extendedKeyUsage = 1.3.6.1.5.5.7.3.1

EOF

openssl req -x509 -config openssl.cnf -newkey rsa:2048 -days 3650 -out cacert.pem -outform PEM -subj /CN=MyTestCA/ -nodes
openssl x509 -in cacert.pem -out cacert.cer -outform DER
cd ..
mkdir server
cd server
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -out req.pem -outform PEM -subj /CN=$FQHN/O=server/ -nodes
cd ../testca
openssl ca -config openssl.cnf -in ../server/req.pem -out ../server/cert.pem -notext -batch -extensions server_ca_extensions
#cd ../server
#openssl pkcs12 -export -out keycert.p12 -in cert.pem -inkey key.pem -passout pass:MySecretPassword
cd ..
mkdir client
cd client
openssl genrsa -out key.pem 2048
openssl req -new -key key.pem -out req.pem -outform PEM -subj /CN=$FQHN/O=client/ -nodes
cd ../testca
openssl ca -config openssl.cnf -in ../client/req.pem -out ../client/cert.pem -notext -batch -extensions client_ca_extensions
#cd ../client
#openssl pkcs12 -export -out keycert.p12 -in cert.pem -inkey key.pem -passout pass:MySecretPassword


[ -f /etc/rabbitmq/rabbitmq.config.kanku-bak ] || cp /etc/rabbitmq/rabbitmq.config /etc/rabbitmq/rabbitmq.config.kanku-bak

cat <<EOF > /etc/rabbitmq/rabbitmq.config
[
 {rabbit,
  [
   %% {tcp_listeners, [5672]},
   %% {tcp_listeners, [{"127.0.0.1", 5672},
   %%                  {"::1",       5672}]},
   {ssl_listeners, [5671]},
   {ssl_options, [{cacertfile,           "/etc/rabbitmq/testca/cacert.pem"},
                  {certfile,             "/etc/rabbitmq/server/cert.pem"},
                  {keyfile,              "/etc/rabbitmq/server/key.pem"},
                  {verify,               verify_peer},
                  {fail_if_no_peer_cert, false}]}

  ]},
 {kernel,
  [%% Sets the net_kernel tick time.
   %% Please see http://erlang.org/doc/man/kernel_app.html and
   %% http://www.rabbitmq.com/nettick.html for further details.
   %%
   %% {net_ticktime, 60}
  ]},
 {rabbitmq_management,[
 ]},
 {rabbitmq_shovel,
  [{shovels,
    [
    ]}
  ]},
 {rabbitmq_stomp,
  [
  ]},
 {rabbitmq_mqtt,
  [
  ]},
 {rabbitmq_amqp1_0,
  [
  ]},
 {rabbitmq_auth_backend_ldap,
  [
  ]}
].
EOF

rcrabbitmq-server start
