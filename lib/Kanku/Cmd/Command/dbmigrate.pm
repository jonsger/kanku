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
package Kanku::Cmd::Command::dbmigrate;

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
    documentation => 'Run setup in server mode',
);

has devel => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Run setup in developer mode',
);

has dsn => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'dsn for global database',
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/Projects/kanku/share/kanku-schema.db
      return "dbi:SQLite:dbname=".$_[0]->_dbfile;
    }
);

has _dbfile => (
	isa 	=> 'Str',
	is  	=> 'rw',
	lazy	=> 1,
	default => sub { $_[0]->homedir."/.kanku/kanku-schema.db" }
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

sub abstract { "Migrate database on upgrades" }

sub description { "Migrate database on upgrades" }

sub execute {
  my $self    = shift;
  my $logger  = $self->logger;

  my $base_dir = dir($FindBin::Bin)->parent;

  $logger->debug("Using dsn: ".$self->dsn);

  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args	   => [$self->dsn],
    target_dir	   => "$FindBin::Bin/../share"
  );

  # setup database if needed
  $migration->upgrade();

}


__PACKAGE__->meta->make_immutable();

1;
