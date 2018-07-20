package Kanku::REST::JobComment;

use Moose;
with 'Kanku::Roles::REST';

sub list {
  my ($self) = @_;
  my $job_id = $self->params->{'job_id'};
  my $job    = $self->schema->resultset('JobHistory')->find($job_id);
  if (! $job) {
    return {
      result  => 'failed',
      code    => 404,
      message => "job not found with id ($job_id)",
    };
  }
  my $comments = $job->comments;
  my @cl;
  while (my $cm = $comments->next) {
    push @cl, $cm->TO_JSON;
  }
  return { comments => \@cl };
}

sub create {
  my ($self) = @_;

  my $job_id  = $self->params->{job_id};
  my $message = $self->params->{message};
  my $user_id = $self->current_user->{id};

  if ($message && $user_id && $job_id) {
    $self->rset('JobHistoryComment')->create({
        job_id  => $job_id,
        user_id => $user_id,
        comment => $message,
      });

    return {
      result => 'succeed',
      code   => 200,
    };
  }

  return { result => 'failed' };
}

sub update {
  my ($self) = @_;

  my $comment_id  = $self->params->{comment_id};
  my $comment = $self->schema
                  ->resultset('JobHistoryComment')
                  ->find($comment_id);
  if (! $comment) {
    return {
      result  => 'failed',
      code    => 404,
      message => "comment not found with id ($comment_id)",
    };
  }
  my $message = $self->params->{message};
  my $user_id = $self->current_user->{id};

  if ($message && $user_id) {
    if ($comment->user_id != $user_id) {
      return {
        result  => 'failed',
        code    => 403,
        message => "user with id ($user_id) is not allowed to change comments"
                   . ' of user ('.$comment->user_id.')',
      };
    }

    $comment->update({comment=>$message});

    return {
      result => 'succeed',
      code   => 200,
    };
  }

  return { result => 'failed' };
}

sub remove {
  my ($self) = @_;

  my $comment_id  = $self->params->{comment_id};
  my $comment = $self->rset('JobHistoryComment')->find($comment_id);

  if (! $comment) {
    return {
      result  => 'failed',
      code    => 404,
      message => "comment not found with id ($comment_id)",
    };
  }
  my $message = $self->params->{message};
  my $user_id = $self->current_user->{id};

  if ($comment->user_id != $user_id) {
    return {
      result  => 'failed',
      code    => 403,
      message => "user with id ($user_id) is not allowed to change comments of user (".$comment->user_id.q{)},
    };
  }

  $comment->delete;

  return {
    result => 'succeed',
    code   => 200,
  };
}

1;
