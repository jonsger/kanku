# install package rabbitmq-server
zypper -n in rabbitmq-server

# copy unit file for epmd.socket
cp /usr/lib/systemd/system/epmd.socket /etc/systemd/system/

# configure epmd to listen on all interface instead of localhost only
perl -p -i -e 's/127.0.0.1/0.0.0.0/' /etc/systemd/system/epmd.socket

# reload systemd
systemctl daemon-reload

# 
systemctl start epmd
systemctl enable epmd

# check epmd settings
netstat -antp|grep 0.0.0.0:4369

#
systemctl start rabbitmq-server
systemctl enable rabbitmq-server

rabbitmqctl add_vhost /kanku
rabbitmqctl add_user <YOUR_USER> <YOUR_PASSWORD>
rabbitmqctl set_permissions -p /kanku kanku ".*" ".*" ".*"

# check rabbitmq configuration in /opt/kanku/etc/config.yml
# 
#
