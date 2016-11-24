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
package Kanku::Cmd::Command::init;

use Moose;
use Template;
use FindBin;

extends qw(MooseX::App::Cmd::Command);
with "Kanku::Cmd::Roles::Schema";

has default_job => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'default job name in KankuFile',
    lazy          => 1,
    default       => 'kanku-job'
);

has domain_name => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'name of default domain in KankuFile',
    lazy          => 1,
    default       => 'kanku-vm'
);

has qemu_user => (
    traits        => [qw(Getopt)],
    isa           => 'Str',
    is            => 'rw',
    documentation => 'user to run qemu',
    lazy => 1,
    default       => $ENV{USER}
);

has memory => (
    traits        => [qw(Getopt)],
    isa           => 'Int',
    is            => 'rw',
    documentation => 'RAM size of virtual machines (in MB)',
    lazy          => 1,
    default       => 2048
);

has vcpu => (
    traits        => [qw(Getopt)],
    isa           => 'Int',
    is            => 'rw',
    documentation => 'Number of virtual CPU\'s in VM',
    lazy          => 1,
    default       => 2
);

sub abstract { "create KankuFile in your current working directory" }

sub description { "create KankuFile in your current working directory" }

sub execute {
  my $self    = shift;
  my $logger  = Log::Log4perl->get_logger;

  if ( -f 'KankuFile' ) {
    $logger->warn("KankuFile already exists.");
    $logger->warn("  Please remove first if you really want to initalize again.");
    exit 1;
  }


  my $config = {
    INCLUDE_PATH => $FindBin::Bin."/../etc/templates/cmd/",
    INTERPOLATE  => 1,               # expand "$var" in plain text
    #POST_CHOMP   => 1,               # cleanup whitespace
    #PRE_PROCESS  => 'header',        # prefix each template
    #EVAL_PERL    => 1,               # evaluate Perl code blocks
    #RELATIVE     => 1
  };

  # create Template object
  my $template  = Template->new($config);
  my $memory    = $self->memory * 1024;

  # define template variables for replacement
  my $vars = {
	domain_name   => $self->domain_name,
        domain_memory => $memory,
	domain_cpus   => $self->vcpu,
	default_job   => $self->default_job,
	qemu_use      => $self->qemu_user,
  };

  my $output = '';
  # process input template, substituting variables
  $template->process('init.tt2', $vars, "KankuFile")
               || die $template->error()->as_string();


  ( -d ".kanku" ) || mkdir ".kanku";

  $logger->info("KankuFile written");
  $logger->info("Now you can make your modifications");
  $logger->info("Or start you new VM:");
  $logger->info("");
  $logger->info("kanku up");
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
