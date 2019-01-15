package Kanku::YAML;

use YAML;
use Try::Tiny;

sub LoadFile {
  my ($file) = @_;
  my $res;

  try {
    $res = YAML::LoadFile($file);
  } catch {
    die "ERROR while parsing YAML from file '$file': $_\n"
  };
  return $res;
}

sub DumpFile {
  my ($file, $content) = @_;
  my $res;

  try {
    $res = YAML::DumpFile($file, $content);
  } catch {
    die "ERROR while parsing YAML from file '$file': $_\n"
  };
  return $res;
}

1;
