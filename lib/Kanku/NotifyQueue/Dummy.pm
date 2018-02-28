package Kanku::NotifyQueue::Dummy;

use Moose;
use JSON::XS qw/encode_json/;
with 'Kanku::Roles::NotifyQueue';

sub prepare { };

sub send {
  my ($self, $msg) = @_;
  $msg = encode_json($msg) if ref($msg);
  $self->logger->debug($msg);
}

1;
