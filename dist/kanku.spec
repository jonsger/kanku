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
Version:        0.0.1
Release:        0.1
License:        GPL-3.0
Summary:        Development and continuous integration made easy
Url:            https://github.com/M0ses/kanku
Group:          Productivity/Networking/Web/Utilities
Source:         %{name}-%{version}.tar.xz
BuildArch:      noarch
BuildRequires:  perl-macros
BuildRequires:  fdupes
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

Recommends: osc 
Requires: libvirt-daemon-qemu qemu-kvm libvirt-daemon-config-network libvirt-daemon-config-nwfilter
Requires: perl(DBIx::Class::Fixtures)
Requires: perl(Test::Simple)
Requires: perl(YAML)
Requires: perl(Config::Tiny)
Requires: perl(Path::Class)
Requires: perl(Sys::Virt)
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
%defattr(-,root,root)
%doc README.md TODO

%exclude /etc
%dir /opt/kanku
/opt/kanku/public/
/opt/kanku/lib
%dir /opt/kanku/share/
/opt/kanku/share/fixtures
/opt/kanku/share/migrations

%dir /opt/kanku/bin
%attr(755,root,root) /opt/kanku/bin/kanku-scheduler
%attr(755,root,root) /opt/kanku/bin/kanku-apache2.psig
%attr(755,root,root) /opt/kanku/bin/kanku-app.psgi
%attr(755,root,root) /opt/kanku/bin/kanku

%dir /opt/kanku/etc/
%ghost /opt/kanku/etc/config.yml
%config /opt/kanku/etc/console-log.conf
%config /opt/kanku/etc/config.yml.template

%dir /opt/kanku/etc/templates
%dir /opt/kanku/etc/templates/cmd
%config /opt/kanku/etc/templates/cmd/setup.config.yml.tt2
%config /opt/kanku/etc/templates/cmd/init.tt2
%config /opt/kanku/etc/templates/obs-server-26.tt2
%config /opt/kanku/etc/templates/sles11sp3.tt2
%config /opt/kanku/etc/templates/obs-server.tt2

%dir /opt/kanku/etc/jobs
%config /opt/kanku/etc/jobs/obs-server.yml.template
%config /opt/kanku/etc/jobs/sles11sp3.yml.template
%config /opt/kanku/etc/jobs/obs-server-26.yml.template
%config /opt/kanku/etc/log4perl.conf

%dir /etc/sudoers.d
%config (noreplace)  /etc/sudoers.d/kanku

%dir /etc/apache2
%dir /etc/apache2/conf.d
%config (noreplace) /etc/apache2/conf.d/kanku.conf

%dir /etc/profile.d/
%config /etc/profile.d/kanku.sh

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

%changelog
* Thu Mar 10 2016 Frank Schreiner - 0.0.1-0.1
- initial version

