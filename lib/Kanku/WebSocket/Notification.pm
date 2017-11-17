package Kanku::WebSocket::Notification;
use Moose;
use JSON::XS;
use Try::Tiny;

has blocked => (is=>'rw',isa=>'Bool',default=>1);
has conn => (is=>'rw',isa=>'Object');

my $role_to_points = {
  Admin => 30,
  User  => 20,
  Guest => 10
};

sub unblock { $_[0]->blocked(0) }

sub prepare {
  my ($self, $msg) = @_;
  my $result;

  if ( $msg->{type} ) {
    if ( $msg->{type} eq 'task_change' ) {
      $result = {
        title => "Kanku Task $msg->{event} (JobId: $msg->{job_id})",
        link  => "job_result/$msg->{job_id}"
      };
    } elsif ($msg->{type} eq 'job_change') {
      $result =  {
        title => "Kanku Job $msg->{event} (Id: $msg->{id})",
        link  => "job_result/$msg->{id}"
      },
    } elsif ($msg->{type} eq 'daemon_change') {
      $result = {
        title => "Kanku Daemon $msg->{event}",
        link  => "notify"
      }
    }
  }

  if (! $result ) {
    $result = {
      title=>"Kanku Status Notification",
      link => 'notify'
    };
  }

  $result->{body} = $msg->{message};

  return encode_json($result);
}

sub send {
  my ($self, $msg) = @_;
  try {
    if (ref $msg ) {
      $msg = $self->prepare($msg);
    } else {
      $msg = $self->prepare({message=>$msg});
    }
  } catch {
    $msg = $_;
  };
  $self->conn->send($msg) || die "Error while sending $msg";
}

1;
