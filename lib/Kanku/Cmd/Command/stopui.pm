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
package Kanku::Cmd::Command::stopui;

use Moose;
use Log::Log4perl;
use FindBin;


extends qw(MooseX::App::Cmd::Command);

sub abstract { "stop our local webserver, providing the ui" }

sub description { "stop our local webserver, providing the ui" }


sub execute {
  my $self      = shift;

  my $logger    = Log::Log4perl->get_logger;
  my $pid_file  = ".kanku/ui.pid";

  if ( open(PF,"<",$pid_file) ) {
    my $pid = <PF>;
    close PF;

    kill(9,$pid);

    unlink($pid_file);

    $logger->info("Stopped webserver with pid: $pid");

  } else {

    $logger->warn("No pid file found.");

  }

}

1;
