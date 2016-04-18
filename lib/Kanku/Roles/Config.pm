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
package Kanku::Roles::Config;

use Moose::Role;
use Path::Class::File;
use Data::Dumper;
use YAML;

with 'Kanku::Roles::Config::Base';

sub file {
    return Path::Class::File->new($_[0]->app_base_path,'etc','config.yml' . $_[0]->mode);
}

has config => (
  is      => 'rw',
  isa     => 'HashRef',
);

has last_modified => (
  is        => 'rw',
  isa       => "Int",
  default   => 0
);

has mode => (
  is        => 'rw',
  isa       => "Str",
  default   => ''
);

sub _build_config {
    my $self    = shift;
    my $file    = $self->file;
    my $content = $file->slurp();
    return YAML::Load($content);
}

around 'config' => sub {
  my $orig = shift;
  my $self = shift;

  if ( $self->file->stat->mtime > $self->last_modified ) {
    if ( $self->last_modified ) {
      $self->logger->debug("Modification of config file detected. Re-reading");
    } else {
      $self->logger->debug("Initial read of config file");
    }
    $self->last_modified($self->file->stat->mtime);
    return $self->$orig( $self->_build_config() );
  }

  return $self->$orig();
};

sub job_config {
  my $self      = shift;
  return YAML::Load($self->job_config_plain(@_));
}

sub job_config_plain {
  my $self      = shift;
  my $job_name  = shift;
  my $conf_file = Path::Class::File->new($self->app_base_path,'etc','jobs',$job_name.'.yml' . $self->mode);


  my $content = $conf_file->slurp();

  return $content;
}

sub job_list {
  my $self = shift;

  return keys (%{$self->config->{Jobs}});

}

1;

