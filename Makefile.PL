use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'Kanku',
    AUTHOR              => q{Frank Schreiner <fschreiner@suse.de>},
    VERSION_FROM        => 'lib/Kanku.pm',
    ABSTRACT            => 'Tool to test appliances in VM`s',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'              => 0,
        'YAML'                    => 0,
        'Moose'                   => 0,
        'Dancer2'                 => 0.160000,
        'Path::Class'             => 0,
        'Sys::Virt'               => 0,
        'MooseX::Singleton'       => 0,
        'Dancer2::Plugin::REST'   => 0,
        'DBIx::Class'             => 0,
        'Log::Log4perl'           => 0,
        'Template'                => 0,
        'MooseX::App::Cmd'   	  => 0,
        'Expect'	   	          => 0,
        'Net::SSH2'	   	          => 0,
        'Net::IP'	   	          => 0,
        'Dancer2::Plugin::DBIC'   => 0,
        'Dancer2::Plugin::Auth::Extensible'		   	=> 0,
	    'Dancer2::Plugin::Auth::Extensible::Provider::DBIC'	=> 0,
	    'XML::Structured'	      => 0,
	    'Config::Tiny'		      => 0,
	    'DBIx::Class::Migration'  => 0,
	    'DBIx::Class::Fixtures'   => 0,
    },
    EXE_FILES => [qw# 
      bin/kanku 
      bin/kanku-scheduler 
      bin/kanku-apache2.psig
      bin/kanku-app.psgi
    #],
    PREFIX        =>'/opt/kanku',
    LIB           => '/opt/kanku/lib', 
    INSTALLSCRIPT => '/opt/kanku/bin',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Kanku-*' },
);
