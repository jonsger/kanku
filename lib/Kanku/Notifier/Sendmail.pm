package Kanku::Notifier::Sendmail;

use Moose;
use Mail::Sendmail;

with 'Kanku::Roles::Notifier';

sub notify {
  my $self = shift;
  my $text = shift;
  my %mail = (
	%{$self->options},
	subject => $self->short_message,
        message => $self->full_message
  );

  sendmail(%mail) or die "$Mail::Sendmail::error\n";

}


1;

