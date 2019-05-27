package Kanku::Notifier::NSCA;

use Moose;
use Net::NSCA::Client;
#use Template;
use Data::Dumper;
use Kanku::Config;

with 'Kanku::Roles::Notifier';
with 'Kanku::Roles::Logger';

=head1 NAME

Kanku::Notifier::NSCA - A kanku notification module for Nagios NSCA

=head1 DESCRIPTION

Send a notification to a nagios NSCA daemon.

=head1 CONFIGURATION

=head2 GLOBAL

in /etc/kanku/kanku-config.yml:

 Kanku::Notifier::NSCA:
   init:
     encryption_password: ...
     encryption_type: ...
     remote_host: ...
     remote_port: ...
   send_report:
     hostname: <hostname_in_icinga>


=head2 JOB CONFIG FILE

  notifiers:
    -
      use_module: Kanku::Notifier::NSCA
      options:
	send_report:
	  hostname: <hostname_in_icinga>
	  service:  <servicename_in_icinga>
      states: failed,succeed


=head1 SEE ALSO

L<Net::NSCA::Client>

=cut

sub notify {
  my $self = shift;

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
  my $input     = 'nsca.tt';
  my $output    = '';
  # process input template, substituting variables
  $template->process($input, $self->get_template_data(), \$output)
               || die $template->error()->as_string();
  $output =~ s/\n/\\n/g;

  my $nstat;
  if($self->state eq 'succeed') {
    $nstat = $Net::NSCA::Client::STATUS_OK;
  } elsif ($self->state eq 'failed') {
    $nstat = $Net::NSCA::Client::STATUS_CRITICAL;
  } else {
    $nstat = $Net::NSCA::Client::STATUS_WARNING;
  }

  $self->logger->debug("Sending report (status: $nstat  with message: ".$self->short_message);
  my $cfg              = Kanku::Config->instance->config;
  my $pkg              = __PACKAGE__;

  my $global_init_opts = $cfg->{$pkg}->{init}   || {};
  my $init_opts        = $self->options->{init} || {};
  my %iopts            = (%{$global_init_opts}, %{$init_opts});
  if (! %iopts) {
      $self->logger->error("No configuration found for init. Please check the docs!");
  }
  my $nsca             = Net::NSCA::Client->new(%iopts);
  $nsca->send_report(
    %{$cfg->{$pkg}->{send_report} ||{}},
    %{$self->options->{send_report}},
    message => $output,
    status => $nstat
  );

  return;
}

1;
