# DISCLAIMER

This project is in a very early state (pre-alpha), so we not recommend to use on productive machines. 
This guide is written for openSUSE Tumbleweed.
If you wish to use with e.g. Leap, you have to care about some changes in the repository
pathes.

# Project home

https://github.com/M0ses/kanku

# Preparation for Installation

## Configuration of additional software respositories

```
sudo zypper ar http://download.opensuse.org/repositories/home:/M0ses:/Perl/openSUSE_Tumbleweed/home:M0ses:Perl.repo
sudo zypper ar http://download.opensuse.org/repositories/devel:/languages:/perl/openSUSE_Tumbleweed/devel:languages:perl.repo
sudo zypper ref -s
```

## Installation of required perl packages

```
sudo zypper -n in osc git vim-data libvirt libvirt-daemon-qemu qemu-kvm \
  libvirt-daemon-config-network libvirt-daemon-config-nwfilter \
  perl-DBIx-Class-Fixtures perl-Test-Simple perl-YAML perl-Config-Tiny \
  perl-Path-Class perl-Sys-Virt perl-MooseX-App-Cmd perl-Dancer2-Plugin-REST \
  perl-MooseX-Singleton perl-Expect perl-Net-SSH2 perl-Net-IP \
  perl-XML-Structured perl-Dancer-Plugin-DBIC perl-DBIx-Class-Migration \
  perl-Template-Toolkit perl-Log-Log4perl perl-Config-Tiny \
  perl-Dancer2-Plugin-DBIC perl-Dancer2-Plugin-Auth-Extensible \
  perl-Dancer2-Plugin-Auth-Extensible-Provider-DBIC \

cd /tmp
git clone git@github.com:M0ses/Net-OBS-Client.git
cd Net-OBS-Client
perl Makefile.PL
make 
sudo make install

```

## Starting frontend development

```
git clone <uri_to_kanku_repository>
cd kanku
sudo bin/kanku setup --devel

sudo shutdown -r now

# after reboot, login, start termnial and change into your kanku home
```

## Preparing a new Project

```
# cd in project's directory

# init will create a default Kankufile which should give you a good starting 
# point
kanku init
kanku up
```
# FAQ

## How could I setup the database manually ?

```
export DBIC_MIGRATION_SCHEMA_CLASS=Kanku::Schema
export PERL5LIB=./lib:$PERL5LIB

# (optional) dbic-migration status

dbic-migration install

dbic-migration populate
```
