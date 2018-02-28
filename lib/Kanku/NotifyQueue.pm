package Kanku::NotifyQueue;

use Moose;
use Kanku::Config;
use Kanku::NotifyQueue::RabbitMQ;
use Kanku::NotifyQueue::Dummy;

sub new {
  my $self   = shift;
  my $config = Kanku::Config->instance();

  if (ref($config->{'Kanku::RabbitMQ'})) {
    return Kanku::NotifyQueue::RabbitMQ->new(@_);
  }
  return Kanku::NotifyQueue::Dummy->new(@_);
}

1;
