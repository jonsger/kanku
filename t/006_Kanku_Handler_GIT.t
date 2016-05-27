use strict;
use warnings;

use Test::More tests => 4;
use FindBin;
use Path::Class qw/dir/;
use Data::Dumper;

use Kanku::Job;

require_ok('Kanku::Handler::GIT');

### Initialization Section
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($TRACE);  # Set priority of root logger to ERROR

### Application Section
my $logger = get_logger();


my $job = Kanku::Job->new();

$job->context()->{cache_dir} = $FindBin::Bin."/tmp/cache/";
$job->context()->{ipaddress} = "1.2.3.4";

my $git_cache_dir = dir($job->context()->{cache_dir} ,'git');

$git_cache_dir->mkpath();

my $handler = Kanku::Handler::GIT->new(
  job         => $job,
  mirror      => 1,
  giturl      => "http://doesnotmatterforprepare/M0ses/kanku.git",
  remote_url  => "http://github.com/M0ses/kanku.git",
  logger      => $logger
);


$handler->prepare();



exit 0;
