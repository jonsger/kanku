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
package Kanku::Cmd::Command::rjob;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use Kanku::Remote;
use YAML qw/LoadFile DumpFile/;
use POSIX;


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

has id => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  documentation => 'ID of job on your kanku remote instance.',
  required      => 1,
);

has full => (
  traits        => [qw(Getopt)],
  isa           => 'Bool',
  is            => 'rw',
  documentation => 'show full output of error messages',
);

sub abstract { "show result of tasks from a specified remote job" }

sub description { 
  "show result of tasks from a specified job on your remote instance"
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

  my $data = $kr->get_json( path => "job/".$self->id );

  if ( ! $self->full ) {
    foreach my $task (@{$data->{subtasks}}) {
      if ( $task->{result}->{error_message} ) {
        my @lines = split(/\n/,$task->{result}->{error_message});
        my $max_lines = 10;
        if ( @lines > $max_lines ) {
          my $ml = $max_lines;
          my @tmp;
          while ($max_lines) {
            my $line = pop(@lines);
            push(@tmp,$line);
            $max_lines--;
          }
          push(@tmp,"","...","TRUNCATING to $ml lines - use --full to see full output");
          $task->{result}->{error_message} = join("\n",reverse @tmp) . "\n";

        }
      }
    }
  }


  # some useful options (see below for full list)
  my $template_path = Kanku::Config->instance->app_base_path->stringify . '/views/cli/';
  my $config = {
    INCLUDE_PATH  => $template_path,
    INTERPOLATE   => 1,               # expand "$var" in plain text
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin',
  };

  #print Dumper($data);
  # create Template object
  my $template  = Template->new($config);
  my $input 	= 'job.tt';
  my $output 	= '';
  # process input template, substituting variables
  $template->process($input, $data)
               || die $template->error()->as_string();


}

sub duration {
  my $t = shift;
  # Calculate hours
  my $h = floor($t/(60*60));
  # Remove complete hours
  $t = $t - $h*60*60;
  # Calculate minutes
  my $m = floor($t/60);
  # Calculate seconds
  my $s = $t - ( $m * 60 );

  return sprintf("%02d:%02d:%02d",$h,$m,$s);

}

__PACKAGE__->meta->make_immutable;

1;
