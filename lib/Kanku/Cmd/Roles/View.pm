package Kanku::Cmd::Roles::View;

use Carp;
use Moose::Role;
use Template;
use Kanku::Config;

sub view {
  my ($self, $template, $data) = @_;

  my $tt = Template->new({
    INCLUDE_PATH  => Kanku::Config->instance->views_dir . '/cli/',
    INTERPOLATE   => 1,
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  });

  # process input template, substituting variables
  $tt->process($template, $data) || croak($tt->error()->as_string());
}

1;
