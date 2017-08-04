package Kanku::Airbrake;

use MooseX::Singleton;
use Try::Tiny;
use Kanku::Config;
use Data::Dumper;

BEGIN {
  my $cfg = Kanku::Config->instance()->config();
  print Dumper($cfg->{'Kanku::Airbrake'});

  if ( $cfg->{'Kanku::Airbrake'} ) {
    try {
      require Net::Airbrake;
      extends 'Net::Airbrake';
    } catch {
      extends 'Kanku::Airbrake::Dummy';
    };
  } else {
    extends 'Kanku::Airbrake::Dummy';
  }
};

sub new { return $_[0]->SUPER::new(%{Kanku::Config->instance()->config->{'Kanku::Airbrake'} || {}}) }

1;
