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
package Kanku::Handler::FileCopy;

use Moose;
use File::Copy;
use Digest::MD5;
use Kanku::Config;

use feature 'say';

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/src dst/] => (is=>'rw',isa=>'Str',required=>1);
has [qw/md5/] => (is=>'rw',isa=>'Str');

has _changed => (is=>'rw',isa=>'Bool',default=>0);

has _binary => (is=>'rw',isa=>'HashRef',lazy=>1,default=>sub { { } });

has [qw/skip_all_checks skip_check_project skip_check_package skip_download/ ] => (is => 'ro', isa => 'Bool',default => 0 );


sub prepare {
  my $self      = shift;
  my $last_run  = $self->last_run_result();

  my $src;
  open($src,$self->src) || die "Error while opening ".$self->src.": $!\n";

  my $binary = {
    src => $self->src,
    md5 => Digest::MD5->new()->addfile($src)->md5
  };

  $self->_prepare_dst();
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
      ! $self->skip_all_checks and
      -f $self->dst
  ) {
    my $prep_result = $last_run->{prepare}->{binary};
    foreach my $key (qw/src md5/) {
      my $bv = $binary->{$key} || '';
      my $pv = $prep_result->{$key} || '';
      if ( $bv ne $pv ) {
        $self->logger->debug("Change detected");
        $self->_changed(1);
      }
    }

    my $dst;
    open($dst,$self->dst) || die "Error while opening ".$self->dst.": $!\n";
    my $dst_md5 = Digest::MD5->new()->addfile($dst)->digest;
    $self->_changed(1) if ( $binary->{md5} ne $dst_md5 );

  } else {
    $self->_changed(1);
  }
  return {
    code    => 0,
    message => "Found file " . $binary->{src} . " in state changed = " . $self->_changed,
    binary  => $binary,
  };
}

sub execute {
  my $self = shift;

  if ( ! $self->_changed ) {
    $self->logger->debug("Setting job skipped");
    $self->job->skipped(1);
    return {
      code    => 0,
      state   => 'skipped',
      message => "execution skipped because binary did not change since last run"
    };
  }

  my $file = $self->dst;

  if ( -f $self->dst ) {
    unlink $self->dst || die "Error while unlinking file $file: $!\n";
  }

  copy($self->src,$self->dst) || die "Error while copying file '".$self->src."' to '".$self->dst."': $!\n";


  die "Error while copying ".$self->src." to $file" if (! -f $file );

  my $user = Kanku::Config->instance->config()->{qemu}->{user} || 'qemu';

  my ($login,$pass,$uid,$gid) = getpwnam($user)
        or die "$user not in passwd file";

  chown $uid, $gid, $file;


  $self->job()->context()->{vm_image_file} = $file;

  return {
    code    => 0,
    state   => 'succeed',
    message => "Sucessfully downloaded image to $file"
  };
}

sub _prepare_dst {
  my $self = shift;

  if (-d $self->dst ) {
    my @src_parts = split(/\//,$self->src);
    my @dst_parts = split(/\//,$self->dst);
    my $fn = pop(@src_parts);
    $self->dst( '/' . join('/',@dst_parts,$fn));
  }

  # TODO: make_path
}
1;
