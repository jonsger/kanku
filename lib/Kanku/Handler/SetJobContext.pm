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
package Kanku::Handler::SetJobContext;

use Moose;
use Kanku::Util::DoD;
use feature 'say';
use Data::Dumper;
with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/
        api_url         project         package
        vm_image_file   vm_image_url    vm_template_file
        domain_name     host_interface  vm_image_dir
    /
] => (is=>'rw',isa=>'Str');

has [qw/

  skip_all_checks
  skip_check_project
  skip_check_package
  skip_download

/] => (is => 'ro', isa => 'Bool',default => 0 );


has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
#        {
#          param => 'api_url',
#          type  => 'text',
#          label => 'API URL'
#        },
#        {
#          param => 'skip_all_checks',
#          type  => 'checkbox',
#          label => 'Skip all checks'
#        },
#        {
#          param => 'project',
#          type  => 'text',
#          label => 'Project'
#        },
#        {
#          param => 'package',
#          type  => 'text',
#          label => 'Package'
#        },
        {
          param => 'vm_image_dir',
          type  => 'text',
          label => 'VM Image Directory'
        },
        {
          param => 'domain_name',
          type  => 'text',
          label => 'Domain Name'
        },
        {
          param => 'vm_template_file',
          type  => 'text',
          label => 'VM Template File'
        },
      ];
  }
);

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();
  for my $var (qw/domain_name vm_template_file host_interface vm_image_dir/) {
    if ($self->$var()){
      $ctx->{$var} = $self->$var();
    }
  }

  return {
    code    => 0,
    state   => 'succeed',
    message => "Sucessfully prepared job context"
  };
}


1;
