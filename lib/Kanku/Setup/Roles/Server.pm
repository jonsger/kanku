package Kanku::Setup::Roles::Server;

use Moose::Role;
use Net::Domain qw/hostfqdn/;
use Sys::Hostname qw/hostname/;
with 'Kanku::Setup::Roles::Common';

has _dbfile => (
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
        default => sub { $_[0]->app_root."/var/db/kanku-schema.db" }
);

has _apache => (
        isa     => 'Bool',
        is      => 'rw',
);

has _ssl => (
        isa     => 'Bool',
        is      => 'rw',
);

sub _configure_apache {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Enabling apache modules proxy, rewrite, headers");

  for my $mod (qw/proxy rewrite headers/) {
    $self->_run_system_cmd("a2enmod", $mod);
  }

  $self->_create_config_from_template(
    "kanku.conf.mod_proxy.tt2",
    "/etc/apache2/conf.d/kanku.conf",
    {kanku_host => hostfqdn() || hostname()}
  );

  $self->_configure_apache_ssl();

  $self->_run_system_cmd("systemctl", "start", "apache2");
  $self->_run_system_cmd("chkconfig", "apache2", "on");
}

sub _create_ssh_keys {
  my ($self)    = @_;
  if (! -f '/opt/kanku/etc/ssh/id_rsa' ) {
    -d '/opt/kanku/etc/ssh/' || mkdir '/opt/kanku/etc/ssh/';
    `ssh-keygen -b 2048 -t rsa -f /opt/kanku/etc/ssh/id_rsa -q -N ""`
  }
  $self->_chown("/opt/kanku/etc/ssh/id_rsa", "/opt/kanku/etc/ssh/id_rsa.pub");
}

sub _configure_apache_ssl {
  my $self    = shift;
  my $logger  = $self->logger;

  if (! $self->_ssl ) {
    $logger->debug("No SSL confguration requested");
    return 0;
  }
}

1;
