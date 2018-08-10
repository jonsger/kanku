package Kanku::REST::Job;

use Moose;

with 'Kanku::Roles::REST';

use Try::Tiny;
use Kanku::Config;

sub list {
  my ($self) = @_;
  my $limit = $self->params->{limit} || 10;

  my %opts = (
    rows => $limit,
    page => $self->params->{page} || 1,
  );

  my $search = {};
  if ($self->params->{state}) {
    $search->{state} = $self->params->{state};
  } else {
    $search->{state} = [qw/succeed running failed dispatching/];
  }

  if ($self->params->{job_name}) {
	my $jn = $self->params->{job_name};
	$jn =~ s{^\s*(.*[^\s])\s*$}{$1}smx;
	$search->{name}= { like => $jn };
  }

  my $rs = $self->rset('JobHistory')->search(
		  $search,
                  {order_by =>{-desc  =>'id'},
                   %opts,
                  },
              );

  my $rv = [];

  while ( my $ds = $rs->next ) {
    my $data = $ds->TO_JSON();

    if ($self->has_role('User') || $self->has_role('Admin')) {
      $data->{comments} = [];
      my @comments = $ds->comments;
      for my $comment (@comments) {
        push @{$data->{comments}}, $comment->TO_JSON;
      }
    }

    $data->{pwrand} = $ds->pwrand if $self->has_role('Admin');

    push @{$rv}, $data;
  }

  return {
    limit => $limit,
    jobs  => $rv,
  };
}

sub details {
  my ($self) = @_;
  my $job_id = $self->params->{id};
  my $job    = $self->rset('JobHistory')->find($job_id);

  my $subtasks = [];

  my $job_history_subs = $job->job_history_subs();

  while (my $job_history_sub = $job_history_subs->next ) {
    push @{$subtasks}, $job_history_sub->TO_JSON();
  }

  # workerinfo:
  # kata.suse.de:23108:job-3878-340a157a-d27d-4138-97ab-bb8f49b5bef7
  my ($workerhost, $workerpid, $workerqueue) = split /:/smx, $job->workerinfo;

  return {
      id          => $job->id,
      name        => $job->name,
      state       => $job->state,
      subtasks    => $subtasks,
      result      => $job->result || '{}',
      workerhost  => $workerhost,
      workerpid   => $workerpid,
      workerqueue => $workerqueue,
  };
}

sub trigger {
  my ($self) = @_;
  my $name   = $self->params->{name};

  if ( $name ne 'remove-domain') {
    # search for active jobs
    my @active = $self->rset('JobHistory')->search({
      name  => $name,
      state => {'not in' => [qw/skipped succeed failed/]},
    });

    if (@active) {
      return {
        state => 'warning',
        msg   => "Skipped triggering job '$name'."
                 . ' Another job is already running',
      };
    }
  }

  my $jd = {
    name          => $name,
    state         => 'triggered',
    creation_time => time(),
    args 	  => $self->app->request->body,
  };

  $jd->{trigger_user} = $self->current_user->{username} unless $self->has_role('Admin');

  my $job = $self->rset('JobHistory')->create($jd);

  return {state => 'success', msg => "Successfully triggered job '$name' with id ".$job->id};
}

sub config {
  my ($self) = @_;
  my $cfg = Kanku::Config->instance();
  my $rval;

  try {
    $rval = $cfg->job_config_plain($self->params->{name});
  }
  catch {
    $rval = $_;
  };

  return { config => $rval };
}

__PACKAGE__->meta->make_immutable();

1;
