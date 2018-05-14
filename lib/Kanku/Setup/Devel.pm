package Kanku::Setup::Devel;

use Moose;
use Path::Class qw/dir file/;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Roles::Logger';

has homedir => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    default       => sub {
      # dbi:SQLite:dbname=/home/frank/.kanku/kanku-schema.db
      return File::HomeDir->users_home($_[0]->user);
    }
);

has _dbfile => (
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
        default => sub { $_[0]->homedir."/.kanku/kanku-schema.db" }
);

has apiurl => (
  isa    => 'Str',
  is     => 'rw',
);

has osc_user => (
  isa     => 'Str',
  is      => 'rw',
  lazy    => 1,
  default => ''
);

has osc_pass => (
  isa     => 'Str',
  is      => 'rw',
  lazy    => 1,
  default => ''
);

has interactive => (
  isa     => 'Bool',
  is      => 'rw',
  lazy    => 1,
  default => 0,
);

sub setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Running developer setup");

  # ask for user
  $self->_ask_for_user if ( ! $self->user );

  $self->_create_local_settings_dir();

  $self->_set_sudoers();

  $self->_configure_libvirtd_access();

  $self->_setup_database();

  $self->_modify_path_in_bashrc();

  $self->_create_osc_rc();

  # add user to group libvirt
  system("usermod -G libvirt ".$self->user);

  # enable libvirtd
  system("chkconfig libvirtd on");

  $self->_create_default_pool;

  $self->_create_default_network;

  $logger->info("Developer mode setup successfully finished!");
  $logger->info("Please reboot to make sure, libvirtd is coming up properly");
}

sub _create_osc_rc {
  my $self  = shift;

  my $rc        = file($self->homedir,".config/osc/oscrc");
  my $rc_old    = file($self->homedir,".oscrc");

  return if (-f $rc_old);
  return if (-f $rc);

  my $choice = $self->_query_interactive(
    "No oscrc found in your home!
Should it be created (y|N)
",
    0,
    'Bool',
  );

  return unless $choice;

  $rc->parent->mkpath unless -d $rc->parent;

  if ( ! $self->apiurl ) {
     my $default = "https://api.opensuse.org";
     print "Please enter the apiurl of your obs server [$default]\n";
     my $read = <STDIN>;
     chomp($read);
     $self->apiurl($read || $default);
  }

  while ( ! $self->osc_user ) {

     print "Please enter your login user for obs server:\n";
     my $read = <STDIN>;
     chomp($read);
     $self->osc_user($read || '');
  }

  while ( ! $self->osc_pass ) {

     print "Please enter your password for obs server:\n";
     ReadMode('noecho');
     my $read = <STDIN>;
     chomp($read);

     ReadMode(0);
     print "Please repeat your password\n";
     ReadMode('noecho');
     my $read2 = <STDIN>;
     chomp($read2);
     ReadMode(0);

     $self->osc_pass($read || '') if ( $read eq $read2 );
  }

  my $rc_txt = "[general]
apiurl = ".$self->apiurl."

[".$self->apiurl."]
user = ".$self->osc_user."
pass = ".$self->osc_pass."
";

  $rc->spew($rc_txt);
  $self->_chown($rc);
}

sub _create_local_settings_dir {
  my $self = shift;

  my $dir  = dir($self->homedir,".kanku");

  (-d $dir ) || $dir->mkpath();

  $self->_chown($dir);
}

sub _modify_path_in_bashrc {
  my $self      = shift;

  my $choice = $self->_query_interactive(
    "Modification of your '.bashrc'!
Should the following entries be added to your .bashrc
(if no already there)?

export PATH=\"$FindBin::Bin\:\$PATH\"

Your choice (Y|n)?
",
     1,
     'Bool',
  );

  if ($choice) {
    my $rc        = file($self->homedir,".bashrc");
    $self->_backup_config_file($rc);
    my @lines = $rc->slurp;
    my $found = 0;


    foreach my $line (@lines) {
      if ( $line =~ m#^\s*(export\s)?\s*PATH=.*$FindBin::Bin# ) {
        $found = 1
      }
    }

    if ( ! $found ) {
      $self->logger->debug("modifying " . $rc->stringify);
      push(@lines,"export PATH=$FindBin::Bin\:\$PATH\n");
      $rc->spew(\@lines);
    }
  }
}

sub _ask_for_user {
  my $self = shift;

  while ( ! $self->user ) {
    print "Please enter the username of the user who will run kanku [".($ENV{SUDO_USER} || $ENV{USER})."]\n";

    my $answer = <STDIN>;
    chomp($answer);
    $self->user( $answer || $ENV{SUDO_USER} );
  }

  return undef;
}

1;
