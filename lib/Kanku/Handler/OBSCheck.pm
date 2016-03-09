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
package Kanku::Handler::OBSCheck;

use Moose;
use Kanku::Util::DoD;
use feature 'say';
use Data::Dumper;
with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has dod_object => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  default => sub  {
    my $self = shift;
    Kanku::Util::DoD->new(
      skip_all_checks     => $self->skip_all_checks,
      skip_check_project  => $self->skip_check_project,
      skip_check_package  => $self->skip_check_package,
      project             => $self->project,
      package             => $self->package,
      api_url             => $self->api_url,
      use_cache           => $self->use_cache
    )
  },
);

has ['api_url','project','package'] => (is=>'rw',isa=>'Str',required=>1);

has _changed => (is=>'rw',isa=>'Bool',default=>0);

has _binary => (is=>'rw',isa=>'HashRef',lazy=>1,default=>sub { { } });

has [qw/skip_check_project skip_check_package skip_download/ ] => (is => 'ro', isa => 'Bool',default => 0 );
has [qw/offline use_cache skip_all_checks/ ] => (is => 'rw', isa => 'Bool',default => 0 );


has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'api_url',
          type  => 'text',
          label => 'API URL'
        },
        {
          param => 'skip_all_checks',
          type  => 'checkbox',
          label => 'Skip all checks'
        },
        {
          param => 'project',
          type  => 'text',
          label => 'Project'
        },
        {
          param => 'package',
          type  => 'text',
          label => 'Package'
        },
      ];
  }
);

sub prepare {
  my $self      = shift;
  my $ctx       = $self->job()->context();

  $self->offline(1)           if ( $ctx->{offline} );
  $self->use_cache(1)         if ( $ctx->{use_cache} );
  $self->skip_all_checks(1)   if ( $ctx->{skip_all_checks} );

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}

sub execute {
  my $self = shift;
  my $last_run  = $self->last_run_result();
  my $dod       = $self->dod_object();
  my $binary    = $dod->get_image_file_from_url();
  my $ctx       = $self->job()->context();

  # check if $binary is HashRef to prevent Moose from
  # crashing the whole application with an exception
  # if value is undef
  $self->_binary($binary) if ( ref($binary) eq "HashRef");

  # Don`t check for skipping if no last run found
  # or Job was triggered instead of scheduled
  # triggered jobs coming from external
  # and have higher priority
  if (
      $last_run and
      ! $self->job->triggered and
      ! $self->skip_all_checks
  ) {

  # TODO: implement offline mode
  #
    my $prep_result = $last_run->{prepare}->{binary};
    foreach my $key (qw/mtime filename size/) {
      my $bv = $binary->{$key} || '';
      my $pv = $prep_result->{$key} || '';
      if ( $bv ne $pv ) {
        $self->logger->debug("Change detected");
        $self->_changed(1);
      }
    }
  } else {
    $self->_changed(1);
  }

  if ( ! $self->_changed ) {
    $self->logger->debug("Setting job skipped");
    $self->job->skipped(1);
    return {
      code    => 0,
      state   => 'skipped',
      message => "execution skipped because binary did not change since last run"
    };
  }

  if ( ! $self->use_cache ) {
    $dod->check_before_download();
  }

  $ctx->{vm_image_url} = $binary->{url};

  return {
    code    => 0,
    state   => 'succeed',
    message => "Sucessfully checked project ".$self->project." under url ".$self->api_url
  };
}


1;
