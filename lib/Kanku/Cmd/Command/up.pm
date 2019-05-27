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
package Kanku::Cmd::Command::up;

use Moose;
use Carp;

use Kanku::Config;
use Kanku::Job;
use Kanku::JobList;
use Kanku::Dispatch::Local;
use Kanku::Util::VM;

extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Schema';

has offline => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'offline mode',
);

has job_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'j',
    documentation => 'job to run',
);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'name of domain to create',
    lazy		  => 1,
    default		  => sub {
      return Kanku::Config->instance()->config()->{domain_name};
    },
);

has skip_all_checks => (
    traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip all checks when downloading from OBS server e.g.',
);

has skip_check_project => (
  traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip checks if project is ready when downloading from OBS',
);

has skip_check_package => (
  traits        => [qw(Getopt)],
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip checks if package is ready when downloading from OBS',
);

sub abstract { return 'start the job defined in KankuFile'; }

sub description { return 'start the job defined in KankuFile'; }

sub execute {
  my $self    = shift;
  my $logger  = Log::Log4perl->get_logger;
  Kanku::Config->initialize(class => 'KankuFile');
  my $cfg     = Kanku::Config->instance();

  my $schema  = $self->schema;

  croak("Could not connect to database\n") if ! $schema;

  $logger->debug(__PACKAGE__ . '->execute()');

  $self->job_name($cfg->config->{default_job}) if ! $self->job_name;
  my $dn = $self->domain_name;
  my $vm = Kanku::Util::VM->new(domain_name => $dn);
  $logger->debug("Searching for domain: $dn");
  if ($vm->dom) {
    $logger->fatal("Domain $dn already exists");
    exit 1;
  }

  $logger->debug('offline mode: ' . ($self->offline   || 0));
  $logger->debug('job_name: '     . ($self->job_name  || q{}));

  my $job_config = $cfg->job_config($self->job_name);

  croak("No such job found\n") if ! $job_config;

  my $ds = $schema->resultset('JobHistory')->create({
      name          => $self->job_name,
      creation_time => time,
      last_modified => time,
      state         => 'triggered',
  });

  my $job = Kanku::Job->new(
        db_object => $ds,
        id        => $ds->id,
        state     => $ds->state,
        name      => $ds->name,
        skipped   => 0,
        scheduled => 0,
        triggered => 0,
        context   => {
          domain_name        => $dn,
          login_user         => $cfg->config->{login_user},
          login_pass         => $cfg->config->{login_pass},
          use_cache          => $cfg->config->{use_cache},
          offline            => $self->offline            || 0,
          skip_all_checks    => $self->skip_all_checks    || 0,
          skip_check_project => $self->skip_check_project || 0,
          skip_check_package => $self->skip_check_package || 0,
        },
  );

  my $dispatch = Kanku::Dispatch::Local->new(schema=>$schema);
  my $result   = $dispatch->run_job($job);
  my $ctx      = $job->context;
  if ( $result->state eq 'succeed' ) {
      $logger->info('domain_name : ' . ( $ctx->{domain_name} || q{}));
      $logger->info('ipaddress   : ' . ( $ctx->{ipaddress}   || q{}));
  } elsif ( $result->state eq 'skipped' ) {
    $logger->warn('Job was skipped');
    $logger->warn('Please see log to find out why');
  } else {
      $logger->error('Failed to create domain: ' . ( $ctx->{domain_name} || q{}));
      $logger->error("ipaddress   : $ctx->{ipaddress}") if $ctx->{ipaddress};
  };

  return;
}

__PACKAGE__->meta->make_immutable;

1;
