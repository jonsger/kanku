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
package Kanku::Cmd::Command::rguests;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use Kanku::Remote;
use YAML qw/LoadFile DumpFile/;

extends qw(MooseX::App::Cmd::Command);

has apiurl => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'Url to your kanku remote instance',
);

has rc_file => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Config file to load and store settings',
  default       => "$ENV{HOME}/.kankurc"
);

has settings => (
  isa           => 'HashRef',
  is            => 'rw',
  default       => sub {{}}
);

sub abstract { "list guests on your remote kanku instance" }

sub description { 
  "list guests on your remote kanku instance"
}

sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  if ( ! $self->apiurl ) { 
    if ( -f $self->rc_file ) {
      $self->settings(LoadFile($self->rc_file));
      $self->apiurl( $self->settings->{apiurl} || '');
    }
  }

  while ( ! $self->apiurl ) {
    $logger->error("No apiurl found - Please login");
    return 1;
  }

  my $kr =  Kanku::Remote->new(
    apiurl   => $self->apiurl,
  );

  my $data = $kr->get_json( path => "guest/list" );

  # some useful options (see below for full list)
  my $template_path = Kanku::Config->instance->app_base_path->stringify . '/views/cli/';
  my $config = {
    INCLUDE_PATH  => $template_path,
    INTERPOLATE   => 1,               # expand "$var" in plain text
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  };

  # create Template object
  my $template  = Template->new($config);
  my $input 	= 'guests.tt';
  my $output 	= '';
  # process input template, substituting variables
  $template->process($input, $data)
               || die $template->error()->as_string();


}

sub save_settings {
  my $self    = shift;

  DumpFile($self->rc_file,$self->settings);

  return 0;
};

__PACKAGE__->meta->make_immutable;

1;
