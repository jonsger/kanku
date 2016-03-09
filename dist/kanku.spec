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
Release:        0.0
License:        GPL
Summary:        Kanku - development and continous integration made easy
Url:
Group:
Source:
Patch:
BuildRequires:
PreReq:
Provides:
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
TODO: add some meaningful description

%prep
%setup -q

%build
perl Makefile.PL PREFIX=/opt/kanku LIB=/opt/kanku/lib INSTALLSCRIPT=/opt/kanku/bin


%install
%perl_process_packlist
make install DESTDIR=%{buildroot}
%perl_gen_filelist

%post

%postun

%files -f %{name}.files
%defattr(-,root,root)
%doc README.md TODO


