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
package Kanku::Util::VM::Console;

use Moose;
use Expect;
use Data::Dumper;
use Kanku::Config;
use Path::Class qw/file/;

with 'Kanku::Roles::Logger';

has ['domain_name','short_hostname','log_file','login_user','login_pass'] => (is=>'rw', isa=>'Str');
has 'prompt' => (is=>'rw', isa=>'Str',default=>'Kanku-prompt: ');
has 'prompt_regex' => (is=>'rw', isa=>'Object',default=>sub { qr/^Kanku-prompt: / });
has _expect_object  => (is=>'rw', isa => 'Object' );
has [qw/grub_seen user_is_logged_in console_connected/] => (is=>'rw', isa => 'Bool' );
has 'connect_uri' => (is=>'rw', isa=>'Str',default=>'qemu:///system');
has ['job_id'] => (is=>'rw', isa=>'Int');

sub init {
  my $self = shift;
  my $cfg_ = Kanku::Config->instance();
  my $cfg  = $cfg_->config();
  my $pkg  = __PACKAGE__;
  my $logger    = $self->logger();


  $ENV{"LANG"} = "C";
  my $command = "virsh";
  my @parameters = ("-c",$self->connect_uri,"console",$self->domain_name);
 
  my $exp = Expect->new;
  $exp->debug($cfg->{$pkg}->{debug} || 0);

  $logger->debug("Config -> $pkg (log_to_file): $cfg->{$pkg}->{log_to_file}");

  if ($cfg->{$pkg}->{log_to_file}) {
    my $lf = file($cfg->{$pkg}->{log_dir},"job-".$self->job_id."-console.log");
    if (! -d $lf->parent() ) {
      $lf->parent->mkpath();
    }
    $logger->debug("Setting logfile '".$lf->stringify()."'");
    $exp->log_file($lf->stringify(),'w');
  }

  $self->_expect_object($exp);
  $exp->spawn($command, @parameters)
    or die "Cannot spawn $command: $!\n";

  # wait 1 min to get virsh console
  my $timeout = 60;

  $exp->expect(
    $timeout,
      [
        'Escape character is \^\]' => sub {
          $_[0]->clear_accum();
          $self->console_connected(1);
        }
      ]
  );

  $exp->expect(
      5,
      [
        'Press any key to continue.' => sub {
          $self->grub_seen(1);
        }
      ]
  );

  if ( $self->grub_seen ) {
    $exp->send("\n\n");
    $exp->clear_accum();
  }

  die "Could not open virsh console within $timeout seconds" if ( ! ( $self->console_connected or $self->grub_seen ));

  return 0;
}

sub login {
  my $self      = shift;
  my $exp       = $self->_expect_object();
  my $timeout   = 300;
  my $logger    = $self->logger();


  my $user      = $self->login_user;
  my $password  = $self->login_pass;

  die "No login_user found in config" if (! $user);
  die "No login_pass found in config" if (! $password);

  my $login_counter = 0;

  if (! $self->grub_seen ) {
    $exp->send_slow(1,"\003","\004");
  }
  $exp->expect(
    $timeout,
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;

          #die "login seems to be failed as login_counter greater than zero" if ($login_counter);
          if ( $exp->match =~ /^(\S+) login: / ) {
            $logger->debug("Found match '$1'");
            $self->short_hostname($1);
            $self->prompt_regex(qr/$1:.*\s+#/);
          }
          $logger->debug(" - Sending username '$user'");
          $exp->send("$user\n");
          $login_counter++;
          exp_continue;
        }
      ],
      [ '^Password: ' =>
        sub {
          my $exp = shift;
          $logger->debug(" - Sending password '$password'");
          $exp->send("$password\n");
        }
      ],
  );
  my $hn = $self->short_hostname();
  my $prompt = $self->prompt_regex;
  $exp->expect(
      5,
      [
        $prompt=>sub {
          my $exp = shift;
          $logger->info(" - Logged in sucessfully: '".$exp->match."'");
        }
      ]
  );
  $self->user_is_logged_in(1);
  $exp->send("export PS1=\"".$self->prompt."\"\n");
  $self->prompt_regex(qr/\r\nKanku-prompt: /);
  $exp->expect(
      5,
      [
        $self->prompt_regex() => sub {
          my $exp = shift;
          $logger->info(" - Prompt set sucessfully: '".$exp->match."'");
        }
      ]
  );
  $exp->clear_accum();
}

sub logout {
  my $self = shift;
  my $exp = $self->_expect_object();

  $exp->send("exit\n");
  my $timeout = 5;
  $exp->expect(
    $timeout,
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;
          $exp->send(chr(29));
          sleep(1);
          #$exp->soft_close();
        }
      ],
  );
  $self->user_is_logged_in(0);
}

=head1 cmd - execute one or more commands on cli

  $con->cmd("mkdir -p /tmp/kanku","mount /tmp/kanku");

=cut

sub cmd {
  my $self    = shift;
  my @cmds    = @_;
  my $exp     = $self->_expect_object();
  my $results = [];
  my $logger  = $self->logger;

  foreach my $cmd (@cmds) {
      $exp->clear_accum();
      $exp->send("$cmd\n");

      my $timeout = 600;
      $exp->expect(
        $timeout,
          [ $self->prompt_regex() =>
            sub {
              my $exp = shift;
              push(@$results,$exp->before());
            }
          ],
      );

      $exp->send("echo \$?\n");

      $exp->expect(
        1,
        [
          $self->prompt_regex() => sub {
            my $exp=shift;
            my $rc = $exp->before();
            $rc =~ s/echo \$\?//;
            $rc =~ s/\r\n//g;
            if ( $rc ) {
              $logger->warn("Execution of command '$cmd' failed with return code '$rc'");
            } else {
              $logger->debug("Execution of command '$cmd' succeed");
            }
          }
        ]
      );
  }

  return $results;
}

__PACKAGE__->meta->make_immutable;

1;
