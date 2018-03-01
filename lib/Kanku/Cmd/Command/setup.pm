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
use Template;
use FindBin;
use Path::Class qw/file dir/;
use FindBin;
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
    #cmd_aliases   => 'X',
    documentation => 'Run setup in server mode',
);

has distributed => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run setup in distributed server mode',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run setup in developer mode',
);

has user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'User who will be running kanku',
);
has images_dir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'directory where vm images will be stored',
    default       => "/var/lib/libvirt/images"
);

has apiurl => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
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
    #cmd_aliases   => 'X',
    lazy          => 1,
    documentation => 'Configure apache with ssl',
    default       => 0
);

has apache => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    lazy          => 1,
    documentation => 'Configure apache',
    default       => 0
);

#has homedir => (
#    traits        => [qw(Getopt)],
#    isa           => 'Str',
#    is            => 'rw',
#    #cmd_aliases   => 'X',
#    documentation => 'home directory for user',
#    lazy          => 1,
#    default       => sub {
#      # dbi:SQLite:dbname=/home/frank/.kanku/kanku-schema.db
#      return File::HomeDir->users_home($_[0]->user);
#    }
#);

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
  $self->server(1) if ($self->distributed);
  $self->_ask_for_install_mode() if ( ! $self->devel and ! $self->server );

  my $setup;
  if ($self->server && $self->distributed) {
    $setup = Kanku::Setup::Server::Distributed->new(
      images_dir  => $self->images_dir,
      apiurl      => $self->apiurl,
      _ssl        => $self->ssl,
      _apache     => $self->apache,
      _apache     => $self->apache,
      _devel      => 0,
    );
  } elsif ($self->server) {
    $setup = Kanku::Setup::Server::Standalone->new(
      images_dir  => $self->images_dir,
      apiurl      => $self->apiurl,
      _ssl        => $self->ssl,
      _apache     => $self->apache,
      _devel      => 0,
    );
  } elsif ($self->devel) {
    $setup = Kanku::Setup::Devel->new(
      #homedir     => $self->homedir,
      user        => $self->user,
      images_dir  => $self->images_dir,
      apiurl      => $self->apiurl,
      osc_user    => $self->osc_user,
      osc_pass    => $self->osc_pass,
      _ssl        => $self->ssl,
      _apache     => $self->apache,
      _devel      => 1,
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
    my $answer = <STDIN>;
    chomp($answer);
    exit 0 if ( $answer == 9 );

    if ( $answer == 1 ) {
      $self->server(1);
      last;
    }

    if ( $answer == 2 ) {
      $self->server(1);
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
