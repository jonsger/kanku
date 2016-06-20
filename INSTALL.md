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
