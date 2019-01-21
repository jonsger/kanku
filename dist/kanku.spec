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
%define kanku_user   kankurun
%define kanku_group  kanku
%define kanku_vardir /var/lib/kanku/

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
BuildRequires:  systemd-rpm-macros


# perl requires for %check
BuildRequires: perl(DBIx::Class::Fixtures)
BuildRequires: perl(Test::Simple)
BuildRequires: perl(YAML)
BuildRequires: perl(Config::Tiny)
BuildRequires: perl(Path::Class)
BuildRequires: perl(Sys::Virt)
BuildRequires: perl(Moose)
BuildRequires: perl(Log::Log4perl)
BuildRequires: perl(MooseX::App::Cmd)
BuildRequires: perl(Dancer2::Plugin::REST)
BuildRequires: perl(MooseX::Singleton)
BuildRequires: perl(Expect)
BuildRequires: perl(Net::SSH2)
BuildRequires: perl(Net::IP)
BuildRequires: perl(Net::OBS::Client)
BuildRequires: perl(XML::Structured)
BuildRequires: perl(DBIx::Class::Migration)
BuildRequires: perl(Template)
BuildRequires: perl(Log::Log4perl)
BuildRequires: perl(Config::Tiny)
BuildRequires: perl(Dancer2::Plugin::DBIC)
BuildRequires: perl(Dancer2::Plugin::Auth::Extensible)
BuildRequires: perl(Dancer2::Plugin::Auth::Extensible::Provider::DBIC)
BuildRequires: perl(File::HomeDir)
BuildRequires: perl(Template::Plugin::Filter::ANSIColor)
BuildRequires: perl(JSON::XS)
BuildRequires: perl(DBIx::Class)
BuildRequires: perl(DBIx::Class::Migration)
BuildRequires: perl(Template::Plugin::Filter::ANSIColor)
BuildRequires: perl(File::LibMagic)
BuildRequires: perl(IO::Uncompress::UnXz)
BuildRequires: perl(Plack)
BuildRequires: perl(Dancer2)
BuildRequires: perl(Dancer2::Plugin::REST)
BuildRequires: perl(XML::XPath)
BuildRequires: perl(Term::ReadKey)
BuildRequires: perl(IPC::Run)
# DBD::SQLite is also provided by perl-DBD-SQLite-Amalgamation
# but perl-DBD-SQLite-Amalgamation is breaks with SQL syntax errors
# at job_histroy_sub table
BuildRequires: perl-DBD-SQLite
BuildRequires: perl(LWP::Protocol::https)
BuildRequires: perl(Mail::Sendmail)
BuildRequires: perl(Archive::Cpio)
BuildRequires: perl(Dancer2)
BuildRequires: perl(Dancer2::Plugin)
BuildRequires: perl(Dancer2::Plugin::REST)
BuildRequires: perl(Dancer2::Plugin::DBIC)
BuildRequires: perl(Dancer2::Plugin::WebSocket)
BuildRequires: perl(Dancer2::Plugin::Auth::Extensible)
BuildRequires: perl(Net::AMQP::RabbitMQ)
BuildRequires: perl(UUID)
BuildRequires: libvirt-daemon

BuildRoot:      %{_tmppath}/%{name}-%{version}-build

Requires: kanku-cli
Requires: kanku-web
Requires: kanku-worker
Requires: kanku-scheduler
Requires: kanku-dispatcher
Requires: kanku-triggerd

%description
kanku is designed to give you a better integration of your kiwi images built
by the Open Build Service (OBS) in your development and testing workflow.

It provides a framework for simple automation of complex setups,
e.g. to prepare your development environment or run simple tests.

%prep
%setup -q

%build
/bin/true

%install
make install DESTDIR=%{buildroot}
%fdupes %{buildroot}/opt/kanku/share
ln -s /usr/sbin/service %{buildroot}%{_sbindir}/rckanku-web
ln -s /usr/sbin/service %{buildroot}%{_sbindir}/rckanku-worker
ln -s /usr/sbin/service %{buildroot}%{_sbindir}/rckanku-dispatcher
ln -s /usr/sbin/service %{buildroot}%{_sbindir}/rckanku-scheduler
ln -s /usr/sbin/service %{buildroot}%{_sbindir}/rckanku-triggerd

%check
# FIXME
#prove -Ilib t/000_use.t

%files
%exclude /etc
%exclude /usr

%package common
Summary: Common files for kanku

Recommends: osc 
Recommends: perl(IO::Uncompress::UnXz)
Recommends: apache2
Requires: libvirt-daemon-qemu qemu-kvm libvirt-daemon-config-network libvirt-daemon-config-nwfilter
Requires: sudo
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
Requires: perl(Const::Fast)
# DBD::SQLite is also provided by perl-DBD-SQLite-Amalgamation
# but perl-DBD-SQLite-Amalgamation is breaks with SQL syntax errors
# at job_histroy_sub table
Requires: perl-DBD-SQLite
Requires: perl(LWP::Protocol::https)
Requires: perl(Mail::Sendmail)
Requires: perl(Archive::Cpio)
Requires: perl(UUID)
Requires: logrotate

Conflicts: perl-DBD-SQLite-Amalgamation

%description common
TODO:
 add a useful description

%post common
%tmpfiles_create %_tmpfilesdir/kanku.conf

%files common
%defattr(-,root,root)
%doc README.md TODO

%dir /usr/lib/kanku
%dir /usr/lib/kanku/lib
%dir /usr/lib/kanku/lib/Kanku
%dir /usr/lib/kanku/lib/Kanku/Daemon

# share contains database related stuff
%dir /usr/share/kanku
/usr/share/kanku/fixtures
/usr/share/kanku/migrations

%attr(755,root,root) /usr/bin/kanku
%attr(755,root,root) /usr/lib/kanku/network-setup.pl

%dir /etc/kanku
%ghost /etc/kanku/config.yml
%dir /etc/kanku/logging/
%config(noreplace) /etc/kanku/logging/console.conf
%config(noreplace) /etc/kanku/logging/network-setup.conf
%config(noreplace) /etc/kanku/logging/default.conf

%dir /etc/kanku/templates
%dir /etc/kanku/templates/cmd
%dir /etc/kanku/templates/cmd/setup
%config /etc/kanku/templates/cmd/init.tt2
%config /etc/kanku/templates/cmd/setup/*
%dir    /etc/kanku/templates/examples-vm/
%config /etc/kanku/templates/examples-vm/obs-server-26.tt2
%config /etc/kanku/templates/examples-vm/sles11sp3.tt2
%config /etc/kanku/templates/examples-vm/obs-server.tt2

%dir /etc/kanku/jobs
%dir /etc/kanku/jobs/examples
%config /etc/kanku/jobs/examples/obs-server.yml
%config /etc/kanku/jobs/examples/obs-server-26.yml
%config /etc/kanku/jobs/examples/sles11sp3.yml

# %exclude %dir /etc/sudoers.d
# %ghost /etc/sudoers.d/kanku

%exclude %dir /usr
%exclude %dir /usr/bin/
%exclude %dir /usr/sbin/
%exclude %dir /usr/share/
%exclude %dir /usr/lib/

%exclude %dir /etc/profile.d
%config /etc/profile.d/kanku.sh

%exclude %dir /etc/logrotate.d/
%config /etc/logrotate.d/kanku-common

%exclude %dir %_tmpfilesdir
%_tmpfilesdir/kanku.conf

%dir /usr/lib/kanku/lib/Kanku/NotifyQueue/
/usr/lib/kanku/lib/Kanku/NotifyQueue/*.pm
/usr/lib/kanku/lib/Kanku/Handler/
/usr/lib/kanku/lib/Kanku/Roles/
/usr/lib/kanku/lib/Kanku/Schema/
/usr/lib/kanku/lib/Kanku/Setup/
/usr/lib/kanku/lib/Kanku/Util/
/usr/lib/kanku/lib/Kanku/Task/
/usr/lib/kanku/lib/OpenStack/
/usr/lib/kanku/lib/Kanku/Config.pm
/usr/lib/kanku/lib/Kanku/Handler.pod
/usr/lib/kanku/lib/Kanku/Notifier
/usr/lib/kanku/lib/Kanku/Job.pm
/usr/lib/kanku/lib/Kanku/RabbitMQ.pm
/usr/lib/kanku/lib/Kanku/Schema.pm
/usr/lib/kanku/lib/Kanku/JobList.pm
/usr/lib/kanku/lib/Kanku/Task.pm
/usr/lib/kanku/lib/Kanku/Airbrake.pm
/usr/lib/kanku/lib/Kanku/NotifyQueue.pm
/usr/lib/kanku/lib/Kanku/GPG.pm
/usr/lib/kanku/lib/Kanku/YAML.pm

%dir /usr/lib/kanku/lib/Kanku/WebSocket
/usr/lib/kanku/lib/Kanku/WebSocket/Notification.pm
/usr/lib/kanku/lib/Kanku/WebSocket/Session.pm

%dir /usr/lib/kanku/lib/Kanku/Airbrake
/usr/lib/kanku/lib/Kanku/Airbrake/Dummy.pm

%dir /usr/lib/kanku/lib/Kanku/LibVirt
/usr/lib/kanku/lib/Kanku/LibVirt/HostList.pm

%dir /usr/lib/kanku/lib/Kanku/Dispatch/
/usr/lib/kanku/lib/Kanku/Dispatch/Local.pm

/usr/lib/kanku/lib/Kanku/Test/

%package cli
Summary: Command line client for kanku
Requires: kanku-common
Requires: libvirt-client
Requires(pre): libvirt-daemon libvirt-daemon-driver-qemu qemu-kvm
Requires(pre): sudo
Requires: perl(Net::AMQP::RabbitMQ)

%description cli
Command line client for kanku, mainly used for setup tasks
and in developer mode

%files cli
%dir /usr/share/kanku/views/cli/
%dir /usr/share/kanku/views/cli/rjob
/usr/share/kanku/views/cli/*.tt
/usr/share/kanku/views/cli/rjob/*.tt
/usr/lib/kanku/lib/Kanku/Cmd/
/usr/lib/kanku/lib/Kanku/Cmd.pm

%package common-server
Summary: Common server files or settings for kanku
Requires(pre): libvirt-daemon libvirt-daemon-driver-qemu qemu-kvm
Requires(pre): shadow

%description common-server
This package contains common server files, settings and dependencies 
for the kanku server components like kanku-worker, kanku-dispatcher,
kanku-web, kanku-scheduler and kanku-triggerd

%pre common-server
getent group %{kanku_group} >/dev/null || groupadd -r %{kanku_group}
getent passwd %{kanku_user} >/dev/null || useradd -r -g %{kanku_group} -G libvirt -d %{kanku_vardir} -s /sbin/nologin -c "user for kanku" %{kanku_user}
exit 0

%files common-server
%defattr(-, root, root)
%dir %attr(755, kankurun, kanku) /var/log/kanku
%dir %attr(755, kankurun, kanku) /var/lib/kanku
%dir %attr(755, kankurun, kanku) /var/lib/kanku/db
%dir %attr(755, kankurun, kanku) /var/cache/kanku
%ghost %dir %attr(755, kankurun, kanku) /run/kanku

%package web
Summary: WebUI for kanku
Requires: kanku-common
Requires: kanku-common-server
Requires: perl(Dancer2::Plugin::WebSocket)
Requires: perl(Twiggy)
Requires: perl(Mail::Message::Body::String)
Requires: perl(Mail::Transport::Send)
Requires: perl(Net::AMQP::RabbitMQ)
Requires: perl(Template::Plugin::JSON::Escape)
Requires: perl(UUID)
Requires: smtp_daemon

%description web
TODO:
 add a useful description

%pre web
%service_add_pre kanku-web.service

%post web
%service_add_post kanku-web.service

%preun web
%service_del_preun kanku-web.service

%postun web
%service_del_postun kanku-web.service

%files web
%attr(755,root,root) /usr/lib/kanku/kanku-app.psgi
%dir %attr(755, kankurun, kanku) /var/lib/kanku/sessions
%dir /usr/share/kanku/views/
%{_unitdir}/kanku-web.service
%{_sbindir}/rckanku-web
/usr/share/kanku/views/admin.tt
/usr/share/kanku/views/guest.tt
/usr/share/kanku/views/index.tt
/usr/share/kanku/views/job.tt
/usr/share/kanku/views/notify.tt
/usr/share/kanku/views/notify_disabled.tt
/usr/share/kanku/views/job_history.tt
/usr/share/kanku/views/job_result.tt
%dir /usr/share/kanku/views/layouts
/usr/share/kanku/views/layouts/main.tt
/usr/share/kanku/views/login.tt
%dir /usr/share/kanku/views/login
/usr/share/kanku/views/login/denied.tt
/usr/share/kanku/views/admin.tt
/usr/share/kanku/views/settings.tt
/usr/share/kanku/views/signup.tt
/usr/share/kanku/views/pwreset.tt
/usr/share/kanku/views/reset_password.tt

%dir /etc/apache2
%dir /etc/apache2/conf.d
%ghost %config (noreplace) /etc/apache2/conf.d/kanku.conf
%config /etc/kanku/jobs/remove-domain.yml

# public contains css/js/bootstrap/jquery etc
/usr/share/kanku/public/
/usr/lib/kanku/lib/Kanku.pm
/usr/lib/kanku/lib/Kanku/REST.pm
%dir /usr/lib/kanku/lib/Kanku/REST
%dir /usr/lib/kanku/lib/Kanku/REST/Admin
/usr/lib/kanku/lib/Kanku/REST/Admin/Role.pm
/usr/lib/kanku/lib/Kanku/REST/Admin/Task.pm
/usr/lib/kanku/lib/Kanku/REST/Admin/User.pm
/usr/lib/kanku/lib/Kanku/REST/Guest.pm
/usr/lib/kanku/lib/Kanku/REST/Job.pm
/usr/lib/kanku/lib/Kanku/REST/JobComment.pm


%package worker
Summary: Worker daemon for kanku

Requires: kanku-common
Requires: kanku-common-server
Requires: perl(Net::AMQP::RabbitMQ)
Requires: perl(UUID)
Requires: perl(Sys::CPU)
Requires: perl(Sys::LoadAvg)
Requires: perl(Sys::MemInfo)

%description worker
A simple remote worker for kanku based on RabbitMQ

%pre worker
%service_add_pre kanku-worker.service

%post worker
%service_add_post kanku-worker.service

%preun worker
%service_del_preun kanku-worker.service

%postun worker
%service_del_postun kanku-worker.service

%files worker
%{_unitdir}/kanku-worker.service
%{_sbindir}/rckanku-worker
%{_sbindir}/kanku-worker
/usr/lib/kanku/lib/Kanku/Daemon/Worker.pm

%package dispatcher
Summary: Dispatcher daemon for kanku

Requires: kanku-common
Requires: kanku-common-server
Requires: perl(Net::AMQP::RabbitMQ)
Requires(pre): sudo
Recommends: rabbitmq-server

%description dispatcher
A simple dispatcher for kanku based on RabbitMQ

%pre dispatcher
%service_add_pre kanku-dispatcher.service

%post dispatcher
%service_add_post kanku-dispatcher.service

%preun dispatcher
%service_del_preun kanku-dispatcher.service

%postun dispatcher
%service_del_postun kanku-dispatcher.service

%files dispatcher
%{_unitdir}/kanku-dispatcher.service
%{_sbindir}/rckanku-dispatcher
%{_sbindir}/kanku-dispatcher
/usr/lib/kanku/lib/Kanku/Daemon/Dispatcher.pm
/usr/lib/kanku/lib/Kanku/Dispatch/RabbitMQ.pm
/usr/share/kanku/views/notifier/

%package scheduler
Summary: Scheduler daemon for kanku
Requires: kanku-common
Requires: kanku-common-server

%description scheduler
A simple scheduler for kanku based on RabbitMQ

%pre scheduler
%service_add_pre kanku-scheduler.service

%post scheduler
%service_add_post kanku-scheduler.service

%preun scheduler
%service_del_preun kanku-scheduler.service

%postun scheduler
%service_del_postun kanku-scheduler.service

%files scheduler
%attr(755,root,root) %{_sbindir}/kanku-scheduler
/usr/lib/kanku/lib/Kanku/Daemon/Scheduler.pm
%{_unitdir}/kanku-scheduler.service
%{_sbindir}/rckanku-scheduler

%package triggerd
Summary: Trigger daemon for kanku
Requires: kanku-common
Requires: kanku-common-server

%description triggerd
A simple triggerd for kanku based on RabbitMQ

%pre triggerd
%service_add_pre kanku-triggerd.service

%post triggerd
%service_add_post kanku-triggerd.service

%preun triggerd
%service_del_preun kanku-triggerd.service

%postun triggerd
%service_del_postun kanku-triggerd.service

%files triggerd
%attr(755,root,root) %{_sbindir}/kanku-triggerd
%{_unitdir}/kanku-triggerd.service
%{_sbindir}/rckanku-triggerd
%dir /usr/lib/kanku/lib/Kanku/Listener
/usr/lib/kanku/lib/Kanku/Daemon/TriggerD.pm
/usr/lib/kanku/lib/Kanku/Listener/RabbitMQ.pm


%package doc
Summary: Documentation files for kanku

%description doc
This package contains the documentation files for kanku

%files doc
%{_defaultdocdir}/kanku/

%changelog
