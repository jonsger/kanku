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
package Kanku::Cmd::Command::dbinit;

use Moose;
use Template;
use FindBin;
use Path::Class qw/file dir/;
use FindBin;
use File::HomeDir;
use Term::ReadKey;
use Template;
use Kanku::Schema;
use Cwd;
use DBIx::Class::Migration;

extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";

has server => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run dbinit in server mode',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run dbinit in developer mode',
);

has dsn => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'dsn for global database',
    lazy          => 1,
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return "dbi:SQLite:dbname=".$_[0]->_dbfile;
    }
);

has _dbfile => (
  isa 	=> 'Str',
  is  	=> 'rw',
  lazy  => 1,
  default => sub {$_[0]->homedir."/.kanku/kanku-schema.db"}
);

has _dbdir => (
	isa 	=> 'Object',
	is  	=> 'rw',
	lazy	=> 1,
	default => sub { file($_[0]->_dbfile)->parent; }
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

  $self->logger->debug("Server mode: ". $self->server );
  if ( $self->server ) {
    $self->_dbfile('/opt/kanku/share/kanku-schema.db');
  }

  my $base_dir = dir($FindBin::Bin)->parent;

  $logger->debug("Using dsn: ".$self->dsn);
  $logger->debug("Using _dbdir: ".$self->_dbdir);

  $self->_dbdir->mkpath unless -d $self->_dbdir;

  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args	   => [$self->dsn],
    target_dir	   => "$FindBin::Bin/../share"
  );

  # setup database if needed
  $migration->install_if_needed(default_fixture_sets => ['install']);
}

__PACKAGE__->meta->make_immutable();

1;
