package Kanku::Setup::Server::Distributed;

use Moose;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Setup::Roles::Server';
with 'Kanku::Roles::Logger';

sub setup {
  my ($self) = @_;
}

1;
