package Kanku::Config::Worker;

use Moose;
use FindBin;
use Path::Class::File;
use YAML;

has 'worker_config_file' => (is=>"rw",isa=>"Str",default=> "$FindBin::Bin/../etc/kanku-worker.yml");

sub load_config {
  my $self = shift;

  my $fh   = Path::Class::File->new($self->worker_config_file);

  my $txt  = $fh->slurp();

  my $yml  = YAML::Load($txt);

  return $yml;   

}

1;
