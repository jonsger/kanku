package OpenStack::API::Role::Service;

use Moose::Role;

has [qw/type name/]		    => ( is => 'rw', isa => 'Str');

has [qw/endpoints endpoints_links/] => ( is => 'rw', isa => 'ArrayRef');


has os_region_name		    => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  default => $ENV{OS_REGION_NAME} || '',
);

has endpoint			    => (
  is	  => 'rw',
  isa	  => 'HashRef',
  lazy	  => 1,
  default => sub {
    my ($self) = @_;

    die "No os_region_name given" if ( @{$self->endpoints} > 1 && ! $self->os_region_name );

    return $self->endpoints->[0] if (! $self->os_region_name );

    my ($result) = grep { $_->{region} eq $self->os_region_name } @{$self->endpoints};

    return ($result);

  }
);
1;
