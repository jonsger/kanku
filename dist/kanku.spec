#
# spec file for package kanku
#
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           kanku
# Version gets set by obs-service-tar_scm
Version:        0.0.0
Release:        0.0
License:        GPL-3.0
Summary:        Development and continuous integration made easy
Url:            https://github.com/M0ses/kanku
Group:          Productivity/Networking/Web/Utilities
Source:         %{name}-%{version}.tar.xz
BuildArch:      noarch
BuildRequires:  perl-macros
BuildRequires:  fdupes
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

Recommends: kanku-cli
Recommends: kanku-web
Recommends: kanku-worker
Recommends: kanku-scheduler
Recommends: kanku-dispatcher

%description
TODO: add some meaningful description
 to be more verbose

%prep
%setup -q

%build
/bin/true

%install
make install DESTDIR=%{buildroot}
%fdupes %{buildroot}/opt/kanku/share

%files
%exclude /etc

%package common
Summary: Common files for kanku

Recommends: osc 
Recommends: perl(IO::Uncompress::UnXz)
Recommends: apache2
Requires: libvirt-daemon-qemu qemu-kvm libvirt-daemon-config-network libvirt-daemon-config-nwfilter
Requires: perl(DBIx::Class::Fixtures)
Requires: perl(Test::Simple)
Requires: perl(YAML)
Requires: perl(Config::Tiny)
Requires: perl(Path::Class)
Requires: perl(Sys::Virt)
Requires: perl(Moose)
Requires: perl(Log::Log4perl)
Requires: perl(MooseX::App::Cmd)
Requires: perl(Dancer2::Plugin::REST)
Requires: perl(MooseX::Singleton)
Requires: perl(Expect)
Requires: perl(Net::SSH2)
Requires: perl(Net::IP)
Requires: perl(Net::OBS::Client)
Requires: perl(XML::Structured)
Requires: perl(DBIx::Class::Migration)
Requires: perl(Template)
Requires: perl(Log::Log4perl)
Requires: perl(Config::Tiny)
Requires: perl(Dancer2::Plugin::DBIC)
Requires: perl(Dancer2::Plugin::Auth::Extensible)
Requires: perl(Dancer2::Plugin::Auth::Extensible::Provider::DBIC)
Requires: perl(File::HomeDir)
Requires: perl(Template::Plugin::Filter::ANSIColor)
Requires: perl(Sys::Guestfs)
Requires: perl(JSON::XS)
Requires: perl(DBIx::Class)
Requires: perl(DBIx::Class::Migration)
Requires: perl(Template::Plugin::Filter::ANSIColor)
Requires: perl(File::LibMagic)
Requires: perl(IO::Uncompress::UnXz)
Requires: perl-Plack
Requires: perl(Dancer2)
Requires: perl(Dancer2::Plugin::REST)
Requires: perl(XML::XPath)
Requires: perl(Term::ReadKey)
Requires: perl(IPC::Run)
# DBD::SQLite is also provided by perl-DBD-SQLite-Amalgamation
# but perl-DBD-SQLite-Amalgamation is breaks with SQL syntax errors
# at job_histroy_sub table
Requires: perl-DBD-SQLite
Requires: perl(LWP::Protocol::https)
Requires: perl(Mail::Sendmail)

%description common
TODO:
 add a useful description


%files common
%defattr(-,root,root)
%doc README.md TODO

%dir /opt/kanku
%dir /opt/kanku/lib
%dir /opt/kanku/lib/Kanku
%dir /opt/kanku/lib/Kanku/Daemon

# share contains database related stuff
%dir /opt/kanku/share/
/opt/kanku/share/fixtures
/opt/kanku/share/migrations

%dir /opt/kanku/bin
%attr(755,root,root) /opt/kanku/bin/kanku
%attr(755,root,root) /opt/kanku/bin/kanku-network-setup.pl

%dir /opt/kanku/etc/
%ghost /opt/kanku/etc/config.yml
%config /opt/kanku/etc/console-log.conf
%config /opt/kanku/etc/kanku-network-setup-logging.conf
%config /opt/kanku/etc/config.yml.template

%dir /opt/kanku/etc/templates
%dir /opt/kanku/etc/templates/cmd
%config /opt/kanku/etc/templates/cmd/setup.config.yml.tt2
%config /opt/kanku/etc/templates/cmd/init.tt2
%config /opt/kanku/etc/templates/obs-server-26.tt2
%config /opt/kanku/etc/templates/sles11sp3.tt2
%config /opt/kanku/etc/templates/obs-server.tt2

%dir /opt/kanku/etc/jobs
%dir /opt/kanku/etc/jobs/examples
%config /opt/kanku/etc/jobs/examples/obs-server.yml
%config /opt/kanku/etc/jobs/examples/obs-server-26.yml
%config /opt/kanku/etc/jobs/examples/sles11sp3.yml

%config(noreplace) /opt/kanku/etc/log4perl.conf

%dir /etc/sudoers.d
%config (noreplace)  /etc/sudoers.d/kanku

%dir /etc/profile.d/
%config /etc/profile.d/kanku.sh

/opt/kanku/lib/Kanku/Handler/
/opt/kanku/lib/Kanku/Roles/
/opt/kanku/lib/Kanku/Schema/
/opt/kanku/lib/Kanku/Setup/
/opt/kanku/lib/Kanku/Util/
/opt/kanku/lib/Kanku/Task/
/opt/kanku/lib/OpenStack/
/opt/kanku/lib/Kanku/Config.pm
/opt/kanku/lib/Kanku/Handler.pod
/opt/kanku/lib/Kanku/Notifier
/opt/kanku/lib/Kanku/Job.pm
/opt/kanku/lib/Kanku/MQ.pm
/opt/kanku/lib/Kanku/Schema.pm
/opt/kanku/lib/Kanku/JobList.pm
/opt/kanku/lib/Kanku/Task.pm

%package cli
Summary: Command line client for kanku
Requires: kanku-common

%description cli
TODO:
 add a useful description

%files cli
%dir /opt/kanku/views/cli/
/opt/kanku/views/cli/guests.tt
/opt/kanku/views/cli/job.tt
/opt/kanku/views/cli/jobs.tt
%dir /opt/kanku/views/cli/rjob
/opt/kanku/views/cli/rjob/*.tt
/opt/kanku/lib/Kanku/Cmd/
/opt/kanku/lib/Kanku/Cmd.pm

%package web
Summary: WebUI for kanku
Requires: kanku-common

%description web
TODO:
 add a useful description

%files web
%attr(755,root,root) /opt/kanku/bin/kanku-apache2.psig
%attr(755,root,root) /opt/kanku/bin/kanku-app.psgi
%dir /opt/kanku/views/
/opt/kanku/views/admin.tt
/opt/kanku/views/guest.tt
/opt/kanku/views/index.tt
/opt/kanku/views/job.tt
/opt/kanku/views/job_history.tt
%dir /opt/kanku/views/layouts
/opt/kanku/views/layouts/main.tt
/opt/kanku/views/login.tt
%dir /opt/kanku/views/login
/opt/kanku/views/login/denied.tt
/opt/kanku/views/request_roles.tt
/opt/kanku/views/settings.tt
/opt/kanku/views/signup.tt

%dir /etc/apache2
%dir /etc/apache2/conf.d
%config (noreplace) /etc/apache2/conf.d/kanku.conf

# public contains css/js/bootstrap/jquery etc
/opt/kanku/public/
/opt/kanku/lib/Kanku.pm

%package worker
Summary: Worker daemon for kanku

Requires: kanku-common
Requires: perl(Net::AMQP::RabbitMQ)
Requires: perl(UUID)
Requires: perl(Sys::CPU)
Requires: perl(Sys::LoadAvg)
Requires: perl(Sys::MemInfo)

%description worker
A simple remote worker for kanku based on RabbitMQ

%files worker
/opt/kanku/bin/kanku-worker
/opt/kanku/lib/Kanku/Daemon/Worker.pm

%package dispatcher
Summary: Dispatcher daemon for kanku

Requires: kanku-common
Requires: perl(Net::AMQP::RabbitMQ)
Recommends: rabbitmq-server

%description dispatcher
A simple dispatcher for kanku based on RabbitMQ

%files dispatcher
/opt/kanku/bin/kanku-dispatcher
/opt/kanku/lib/Kanku/Daemon/Dispatcher.pm
/opt/kanku/lib/Kanku/Dispatch

%package scheduler
Summary: Scheduler daemon for kanku
Requires: kanku-common

%description scheduler
A simple scheduler for kanku based on RabbitMQ

%files scheduler
%attr(755,root,root) /opt/kanku/bin/kanku-scheduler
/opt/kanku/lib/Kanku/Daemon/Scheduler.pm

%changelog
