#!/bin/bash

KANKU_USER=$1
# for debugging
apt-get install -y vim vim-common make git-core sudo build-essential localehelper libssh2-1-dev


# install distribution packages
apt-get install -y libsys-virt-perl libvirt-bin libvirt-clients libvirt-daemon libdancer2-perl libdancer2-plugin-database-perl libnet-ssh2-perl libmoose-perl libmoosex-app-cmd-perl libmoosex-singleton-perl libjson-perl libmodule-build-perl libexpect-perl libdbix-class-helpers-perl libdbix-class-perl libdbix-class-deploymenthandler-perl libdbd-sqlite3-perl libuuid-perl libssl-dev libipc-system-simple-perl libfile-libmagic-perl libfile-which-perl libmath-int64-perl libalgorithm-diff-perl libalgorithm-merge-perl libarchive-cpio-perl libb-utils-perl libclass-singleton-perl libclass-unload-perl libconfig-ini-perl libconfig-ini-reader-ordered-perl libconst-fast-perl libcpan-meta-check-perl libcrypt-saltedhash-perl libcurry-perl libdata-dump-streamer-perl libdata-dumper-concise-perl libdata-visitor-perl libdatetime-perl libdbix-class-datetime-epoch-perl libdatetime-format-builder-perl libdatetime-format-dateparse-perl libdatetime-format-mysql-perl libdatetime-format-pg-perl libdatetime-format-sqlite-perl libdatetime-format-strptime-perl libdatetime-locale-perl libdatetime-timezone-perl libdbicx-sugar-perl libdbicx-testdatabase-perl libdbix-class-deploymenthandler-perl libdbix-class-inflatecolumn-fs-perl libdbix-class-schema-loader-perl libdbix-class-uuidcolumns-perl libdevel-confess-perl libextutils-config-perl libb-hooks-op-annotation-perl libextutils-depends-perl libextutils-helpers-perl libextutils-installpaths-perl libfile-copy-recursive-perl libfile-homedir-perl libfile-share-perl libfile-sharedir-install-perl libfile-sharedir-projectdistdir-perl libfile-which-perl libhttp-browserdetect-perl libio-all-perl liblingua-en-findnumber-perl liblingua-en-inflect-number-perl liblingua-en-inflect-phrase-perl liblingua-en-number-isordinal-perl liblingua-en-tagger-perl liblingua-en-words2nums-perl liblingua-pt-stemmer-perl liblingua-stem-perl liblingua-stem-perl liblingua-stem-perl liblingua-stem-perl liblingua-stem-snowball-da-perl libmemoize-expirelru-perl libmixin-linewise-perl libmodule-build-tiny-perl libmoosex-traits-pluggable-perl libmoosex-types-loadableclass-perl libnet-ip-perl libnet-ip-xs-perl libpath-finddev-perl libpath-isdev-perl libscalar-list-utils-perl libsession-token-perl libsnowball-norwegian-perl libsnowball-swedish-perl libstring-camelcase-perl libstring-toidentifier-en-perl libsub-uplevel-perl libtask-weaken-perl libtest-api-perl libtest-compile-perl libtest-deep-perl libtest-differences-perl libtest-exception-perl libtest-failwarnings-perl libspecio-perl libtest-fatal-perl libtest-file-perl libtest-file-sharedir-perl libtest-mockobject-perl libattean-perl libtest-modern-perl libtest-most-perl libtest-nowarnings-perl libtest-requires-perl libtest-tempdir-tiny-perl libtest-utf8-perl libtest-warn-perl libtest-warnings-perl libtext-diff-perl libtext-german-perl libtext-unidecode-perl libtie-toobject-perl libuniversal-can-perl libuniversal-isa-perl libuniversal-exports-perl libuniversal-require-perl libxml-structured-perl libyaml-syck-perl curl liblzma-dev

# Generate locales
locale-gen de_DE.UTF-8

# install newest cpanminus
curl -L https://cpanmin.us | perl - App::cpanminus

# Install perls RabbitMq packages
cpanm --notest --install --skip-installed Net::AMQP::RabbitMQ
cpanm --installdeps --skip-installed /tmp/kanku

# Install Net::OBS::Client
git clone https://github.com/M0ses/Net-OBS-Client /tmp/Net-OBS-Client
cd /tmp/Net-OBS-Client;\
  perl Makefile.PL ;\
  make ;\
  make test ;\
  make install\


# Get kanku
git clone https://github.com/M0ses/kanku /tmp/kanku || /bin/true

# Install kanku
make -C /tmp/kanku install

# create kanku user
adduser $KANKU_USER sudo
adduser $KANKU_USER libvirt
cp /tmp/kanku/dist/sudoers-kanku-setup /etc/sudoers.d/kanku-setup

# only needed on ubuntu
ln -s /usr/bin/kvm /usr/bin/qemu-kvm
