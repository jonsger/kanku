# Copyright (c) 2015 SUSE LLC
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
package Kanku::Roles::Daemon;

use Moose::Role;
use Getopt::Long;
use Path::Class::File;
use Path::Class::Dir;
use POSIX ":sys_wait_h";
use FindBin;
use Log::Log4perl;
use Kanku::Config;

with 'Kanku::Roles::Logger';

requires 'run';

has daemon_options => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {
    my ($self) = @_;
    my $opts = {};
    GetOptions(
      $opts,
      'stop',
      'foreground|f'
    ) || die $self->print_usage();
    return $opts;
  }
);

has daemon_basename => (
  is => 'rw',
  isa => 'Str',
  default => sub { Path::Class::File->new($0)->basename }
);

has logger_conf => (
  is => 'rw',
  isa => 'Str',
  default => "$FindBin::Bin/../etc/log4perl.conf"
);

has run_dir => (
  is => 'rw',
  isa => 'Object',
  default => sub { 
    my $rd = Path::Class::Dir->new("$FindBin::Bin/../var/run");
    $rd->mkpath if (! -d $rd);
    return $rd
  }
);

has pid_file => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  default => sub { 
    my ($self) = @_;
    Path::Class::File->new($self->run_dir,$self->daemon_basename.".pid"); 
  }
);

has shutdown_file => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  default => sub { 
    my ($self) = @_;
    Path::Class::File->new($self->run_dir,$self->daemon_basename.".shutdown") 
  }
);

sub print_usage {
  my ($self) = @_;
  my $basename = $self->daemon_basename;

  return "\nUsage: $basename [--stop]\n";
}

sub prepare_and_run {
  my ($self) = @_;

  Kanku::Config->initialize();

  $self->setup_logging();

  $self->initialize_shutdown if ($self->daemon_options->{stop});

  $self->check_pid if ( -f $self->pid_file );

  $self->logger->info("Starting service ".ref(__PACKAGE__));

  $SIG{'INT'} = $SIG{'TERM'} = sub { $self->initialize_shutdown };

  # daemonize
  if (! $self->daemon_options->{foreground}) {
    exit 0 if fork();
  }

  $self->pid_file->spew("$$");

  $self->run;

  $self->finalize_shutdown();

}

sub setup_logging {
  my ($self) = @_;

  if ( $self->daemon_options->{foreground} ) {
    $self->logger_conf("$FindBin::Bin/../etc/console-log.conf");
  }
  Log::Log4perl->init($self->logger_conf);
}

sub initialize_shutdown {
  my ($self) = @_;

  # nothing should be running if no pid_file exists
  exit 0 if (! -f  $self->pid_file);

  my $pid = $self->pid_file->slurp;

  if (kill(0,$pid)) {
    $self->shutdown_file->touch();
  } else {
    $self->logger->warn("Process $pid seems to be died unexpectedly");
    $self->pid_file->remove() 
  }

  exit 0;
}

sub finalize_shutdown {
  my ($self) = @_;

  $self->shutdown_file->remove();
  $self->pid_file->remove();

  $self->logger->info("Shutting down service ".ref(__PACKAGE__));

  exit 0;
}

sub check_pid {
  my ($self) = @_;

  my $pid = $self->pid_file->slurp;

  if (kill(0,$pid)) {
    die "Another instance already running with pid $pid\n";
  }

  $self->logger->warn("Process $pid seems to be died unexpectedly");
  $self->pid_file->remove() 

}

sub detect_shutdown {
  my ($self) = @_;
  return 1 if ( -f $self->shutdown_file );
  return 0;
}
1;
