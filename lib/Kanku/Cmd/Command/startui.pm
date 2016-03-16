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
package Kanku::Cmd::Command::startui;

use Moose;
use Log::Log4perl;
use FindBin;


extends qw(MooseX::App::Cmd::Command);

sub abstract { "start an simple webserver to access web ui under http://localhost:5000" }

sub description { "start an simple webserver to access web ui under http://localhost:5000" }


sub execute {
  my $self      = shift;
  my $pid_file  = ".kanku/ui.pid";
  my $logger    = Log::Log4perl->get_logger;


  if ( -f $pid_file ) {
    $logger->warn("WebUI already running! Please run stopui before or connect to http://localhost:5000");
    exit 1;
  }

  my $pid = fork();

  if ( $pid == 0 ) {

    my $log_file = ".kanku/ui.log";

    # autoflush
    $| = 1;

    local *STDOUT;
    local *STDERR;

    require Plack::Runner;

    open(STDOUT,'>>',$log_file);
    open(STDERR,'>>',$log_file);

    require Kanku;
    my $runner = Plack::Runner->new;
    $runner->run(Kanku->to_app);

    close STDOUT;
    close STDERR;

    exit 0;

  } else {

    open(PF,">",".kanku/ui.pid");
    print PF $pid;
    close PF;

    my $logger  = Log::Log4perl->get_logger;
    $logger->info("Started webserver with pid: $pid");
    $logger->info("Please connect to http://localhost:5000");

  }

  exit 0;

}

__PACKAGE__->meta->make_immutable;

1;
