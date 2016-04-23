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
package Kanku::Roles::Handler;


use Moose::Role;

requires 'execute';


has 'last_run_result' => (
  is => 'rw',
  isa => 'HashRef'
);

has 'job_definition' => (
  is => 'rw',
  isa => 'HashRef'
);

has 'logger' => (
  is => 'rw',
  isa => 'Object'
);

has 'job' => (
  is => 'rw',
  isa => 'Object'
);

has 'schema' => (
  is  => 'rw',
  isa => 'Object'
);

sub prepare {

  return {
    code    => 0,
    message => "Nothing to do!"
  }

}

sub finalize {

  return {
    code    => 0,
    message => "Nothing to do!"
  }

}


1; 

