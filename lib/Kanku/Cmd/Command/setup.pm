# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Cmd::Command::setup;

use Moose;
use Path::Class qw/file dir/;
use File::HomeDir;
use Term::ReadKey;
use Cwd;
use DBIx::Class::Migration;
use IPC::Run qw/run timeout/;
use Sys::Virt;
use Sys::Hostname;
use Net::Domain qw/hostfqdn/;

use Kanku::Schema;
use Kanku::Setup::Devel;
use Kanku::Setup::Server::Distributed;
use Kanku::Setup::Server::Standalone;

extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";
with "Kanku::Roles::Logger";

has server => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Run setup in server mode',
);

has distributed => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Run setup in distributed server mode',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Run setup in developer mode',
);

has user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'User who will be running kanku',
);
has images_dir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'directory where vm images will be stored',
    default       => "/var/lib/libvirt/images"
);

has apiurl => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'url to your obs api',
    default       => "https://api.opensuse.org"
);

has osc_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login user for obs api',
    lazy          => 1,
    default       => ''
);

has osc_pass => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login password obs api',
    lazy          => 1,
    default       => ''
);

has dsn => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'dsn for global database',
);

has ssl => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Configure apache with ssl',
    default       => 0
);

has apache => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Configure apache',
    default       => 0
);

has mq_host => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Host for rabbitmq (distributed setup only)',
    default       => 'localhost'
);

has mq_vhost => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'VHost for rabbitmq (distributed setup only)',
    default       => '/kanku'
);

has mq_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Username for rabbitmq (distributed setup only)',
    default       => 'kanku'
);

has mq_pass => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Password for rabbitmq (distributed setup only)',
    default       => sub {
       my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
       join '', map $alphanumeric[rand @alphanumeric], 0..12;
    }
);

has interactive => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    cmd_aliases   => 'i',
    documentation => 'Interactive Mode - more choice/info how to configure your system',
    default       => 0,
);

has dns_domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str|Undef',
    is            => 'rw',
    lazy          => 1,
    documentation => 'DNS domain name to use in libvirt network configuration',
    default       => 'kanku.site',
);

sub abstract { "Setup local environment to work as server or developer mode." }

sub description { "
Setup local environment to work as server or developer mode.
Installation wizard which asks you several questions,
how to configure your machine.

";
}

sub execute {
  my $self    = shift;
  my $logger  = $self->logger;

  # effective user id
  if ( $> != 0 ) {
    $logger->fatal("Please start setup as root");
    exit 1;
  }

  ### Get information
  # ask for mode
  $self->_ask_for_install_mode() unless ($self->devel or $self->server or $self->distributed );

  my $setup;

  if ($self->distributed) {
    $setup = Kanku::Setup::Server::Distributed->new(
      images_dir      => $self->images_dir,
      apiurl          => $self->apiurl,
      _ssl            => $self->ssl,
      _apache         => $self->apache,
      _devel          => 0,
      mq_user         => $self->mq_user,
      mq_vhost        => $self->mq_vhost,
      mq_pass         => $self->mq_pass,
      dns_domain_name => $self->dns_domain_name,
    );
  } elsif ($self->server) {
    $setup = Kanku::Setup::Server::Standalone->new(
      images_dir      => $self->images_dir,
      apiurl          => $self->apiurl,
      _ssl            => $self->ssl,
      _apache         => $self->apache,
      _devel          => 0,
      dns_domain_name => $self->dns_domain_name,
    );
  } elsif ($self->devel) {
    $setup = Kanku::Setup::Devel->new(
      user            => $self->user,
      images_dir      => $self->images_dir,
      apiurl          => $self->apiurl,
      osc_user        => $self->osc_user,
      osc_pass        => $self->osc_pass,
      _ssl            => $self->ssl,
      _apache         => $self->apache,
      _devel          => 1,
      interactive     => $self->interactive,
      dns_domain_name => $self->dns_domain_name,
    );
  } else {
    die "No valid setup mode found";
  }

  $setup->dsn($self->dsn) if $self->dsn;

  $setup->setup();
}

sub _ask_for_install_mode {
  my $self  = shift;

  print "
Please select installation mode :

(1) server (standalone)
(2) server (distributed)
(3) devel

(9) Quit setup
";

  while (1) {
    my $answer = <>;
    chomp($answer);
    exit 0 if ( $answer == 9 );

    if ( $answer == 1 ) {
      $self->server(1);
      last;
    }

    if ( $answer == 2 ) {
      $self->distributed(1);
      last;
    }

    if ( $answer == 3 ) {
      $self->devel(1);
      last;
    }
  }
}

__PACKAGE__->meta->make_immutable();

1;
