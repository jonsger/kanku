package Kanku::Roles::Helpers;

use Moose::Role;

sub dump_it {
    my ($self, @data) = @_;
    my $d = Data::Dumper->new(\@data);
    $d
      ->Indent(0)
      ->Terse(1)
      ->Sortkeys(1)
      ->Quotekeys(0)
      ->Deparse(1);

    return $d->Dump();
}

1;
