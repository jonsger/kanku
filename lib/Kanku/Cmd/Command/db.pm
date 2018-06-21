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
package Kanku::Cmd::Command::db;

use Moose;
use Path::Class qw/file dir/;
use File::HomeDir;
use Term::ReadKey;
use Kanku::Schema;
use Cwd;
use DBIx::Class::Migration;

extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";

has server => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 's',
    documentation => 'Use database from system (/var/lib/kanku/db/kanku-schema.db',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'd',
    documentation => 'Use database in your $HOME/.kanku/kanku-schema.db directory',
);

has dsn => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'dsn for global database',
    lazy          => 1,
    default       => sub {
      return "dbi:SQLite:dbname=".$_[0]->dbfile;
    }
);

has upgrade => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'u',
    documentation => 'Run database upgrade',
);

has install => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'i',
    documentation => 'Run database installation',
);

has dbfile => (
  traits        => [qw(Getopt)],
  isa 	=> 'Str',
  is  	=> 'rw',
  lazy  => 1,
  default => sub {
    my ($self) = @_;
    return $self->server 
      ? '/var/lib/kanku/db/kanku-schema.db'
      : $self->homedir."/.kanku/kanku-schema.db"
  },
);

has _dbdir => (
	isa 	=> 'Object',
	is  	=> 'rw',
	lazy	=> 1,
	default => sub { return file($_[0]->dbfile)->parent; }
);

has homedir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'home directory for user',
    lazy          => 1,
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return File::HomeDir->users_home($ENV{USER});
    }
);

has share_dir => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'directory where migrations and fixtures are stored',
    lazy          => 1,
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return File::HomeDir->users_home($ENV{USER});
    }
);

has logger => (
  isa   => 'Object',
  is    => 'rw',
  lazy  => 1,
  default => sub { Log::Log4perl->get_logger }
);

sub abstract { "Initialize database" }

sub description { "Initialize database" }

sub execute {
  my $self    = shift;
  my $logger  = $self->logger;


  $logger->debug("Using dsn: ".$self->dsn);
  $logger->debug("Using share_dir: ".$self->share_dir);
  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args	   => [$self->dsn],
    target_dir	   => $self->share_dir
  );

  # setup database if needed
  if ($self->install) {
    if (! -d $self->_dbdir) {
      $logger->debug('Creating _dbdir: '.$self->_dbdir);
      $self->_dbdir->mkpath;
    }
    $migration->install_if_needed(default_fixture_sets => ['install']);
  } elsif ($self->upgrade) {
    $migration->upgrade();
  } else {
    $self->logger->error("Please specify one of the commands (--install|--upgrade)");
  }
}

__PACKAGE__->meta->make_immutable();

1;
