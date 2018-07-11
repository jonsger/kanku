package Kanku::Notifier::Sendmail;

use Moose;
use Mail::Sendmail;
use Template;

use Kanku::Config;

with 'Kanku::Roles::Notifier';
with 'Kanku::Roles::Logger';

sub notify {
  my $self = shift;
  my $text = shift;
  my $data = {
    message => $self->full_message,
    job_id  => $self->job_id,
  };

  my $template_path = Kanku::Config->instance->views_dir . '/notifier/';

  $self->logger->debug("Using template_path: $template_path");

  my $config = {
    INCLUDE_PATH  => $template_path,
    INTERPOLATE   => 1,               # expand "$var" in plain text
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin',
  };

  # create Template object
  my $template  = Template->new($config);
  my $input     = 'sendmail.tt';
  my $output    = '';
  # process input template, substituting variables
  $template->process($input, $data, \$output)
               || die $template->error()->as_string();

  my %mail = (
	%{$self->options},
	subject => $self->short_message,
        message => $output || 'No output'
  );

  sendmail(%mail) or die "$Mail::Sendmail::error\n";

  return;
}

1;
