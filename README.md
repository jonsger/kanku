# DISCLAIMER

This project is in a very early state (pre-alpha), so we not recommend to use on productive machines. 

# Project home

https://github.com/M0ses/kanku

# Working linux distributions

At the moment kanku works only for 
(at least with this guide, but kanku is pure perl + libvirt + qemu, so it should run on any linux distribution )



* openSUSE Tumbleweed

* openSUSE Leap 42.1

but feel free to send us your patches

# Installation

Please be aware, that you choose the right distribution. 
This example works for openSUSE Tumbleweed.

## Automatic installation with yast one-click-install

You can find a yast one-click-install file in the download repositories

http://download.opensuse.org/repositories/home:/M0ses:/kanku/openSUSE_Tumbleweed/kanku.ymp

## Manual installation

### Configuration of software respositories

```
sudo zypper ar http://download.opensuse.org/repositories/devel:/languages:/perl/openSUSE_Tumbleweed/devel:languages:perl.repo
sudo zypper ar http://download.opensuse.org/repositories/home:/M0ses:/Perl/openSUSE_Tumbleweed/home:M0ses:Perl.repo
sudo zypper ar http://download.opensuse.org/repositories/home:/M0ses:/kanku/openSUSE_Tumbleweed/home:M0ses:kanku.repo
sudo zypper ref -s
```

## Installation of package

```
sudo zypper in kanku
```

# Setup your environment

```
sudo /opt/kanku/bin/kanku setup --devel

sudo shutdown -r now

# after reboot, login, start termnial and change into your kanku home
```

## Preparing a new Project

init will create a default Kankufile which should give you a good starting
point. The option "--memory=..." defines the RAM of the virtual guest and is optional.
Default is 2G of RAM.

```
# create directory 
mkdir MyProject

# cd in project's directory
cd MyProject

kanku init --memory=512
```

# Download, create and start a new guest

```
kanku up
```

# Connect to new machine
Per default, if it exists, your ssh key is added to the authorized keys file
Otherwise you can login with the default password "kankusho".
The default root password is "kankudai".
Please change the password after logging in 1st time for security concerns

```
kanku ssh # (will connect as user kanku)
```
# Concept and interaction with other tools

![Concept Diagram](https://drive.google.com/file/d/0B1Huu8D4Exuwa3JzODY2R3kzaWs/view?usp=sharing)

# FAQ

## How could I setup the database manually ?

```
export DBIC_MIGRATION_SCHEMA_CLASS=Kanku::Schema
export PERL5LIB=./lib:$PERL5LIB

# (optional) dbic-migration status

dbic-migration install

dbic-migration populate
```

# KNOWN ISSUES

* In openSUSE Leap 42.1 you have to enter the root password on each interaction with libvirt.
