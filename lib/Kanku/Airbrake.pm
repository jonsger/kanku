package Kanku::Airbrake;

use MooseX::Singleton;
use Try::Tiny;
use Data::Dumper;
use Devel::StackTrace;

has _ab_object => (is =>'rw',isa=>'Object');
has _backtrace => (is => 'rw', isa => 'ArrayRef', default => sub {[]});

sub initialize {
  my ($self, @opts) = @_;
  my $cfg    = Kanku::Config->instance()->config();

  if ( $cfg->{'Kanku::Airbrake'} ) {
    try {
      require Net::Airbrake;
      $self->_ab_object(Net::Airbrake->new(%{$cfg->{'Kanku::Airbrake'}}));
    } catch {
      require Kanku::Airbrake::Dummy;
      $self->_ab_object(Kanku::Airbrake::Dummy->new());
    };
  } else {
    require Kanku::Airbrake::Dummy;
    $self->_ab_object(Kanku::Airbrake::Dummy->new());
  }
}

sub add_error { my $s = shift; return $s->_ab_object->add_error(@_); }
sub has_error { my $s = shift; return $s->_ab_object->has_error(@_); }
sub send      { my $s = shift; return $s->_ab_object->send(@_);      }
sub notify    { my $s = shift; return $s->_ab_object->notify(@_);    }

sub notify_with_backtrace {
  my ($self, $msg, $index, $options) = @_;
  $self->notify({
      type      => 'Core::die',
      message   => $msg,
      backtrace => $self->backtrace($index)
    },
    $options
  );
}

sub backtrace {
  my ($self,$index) = @_;
  $self->_backtrace([]);
  my $skip_frames = defined($index) ? $index : 3;
  my $dSt = Devel::StackTrace->new(skip_frames => $skip_frames);
  while (my $frame = $dSt->next_frame) {
    push(
      @{$self->_backtrace},
      {
         file     => $frame->filename,
         line     => $frame->line,
         function => $frame->subroutine
      }
    );
  }
  $self->_backtrace([reverse(@{$self->_backtrace})]);
  return $self->_backtrace;
}

1;
