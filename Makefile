CONFIG_FILES = \
	templates/cmd/init.tt2\
	templates/cmd/setup/kanku.conf.mod_perl.tt2\
	templates/cmd/setup/kanku.conf.mod_proxy.tt2\
	templates/cmd/setup/openssl.cnf.tt2\
	templates/cmd/setup/dancer-config.yml.tt2\
	templates/cmd/setup/kanku-config.yml.tt2\
	templates/cmd/setup/net-default.xml.tt2\
	templates/cmd/setup/net-kanku-ovs.xml.tt2\
        templates/cmd/setup/pool-default.xml\
        templates/cmd/setup/rabbitmq.config.tt2\
	templates/examples-vm/obs-server-26.tt2\
	templates/examples-vm/sles11sp3.tt2\
	templates/examples-vm/obs-server.tt2\
	jobs/examples/obs-server.yml\
	jobs/examples/sles11sp3.yml\
	jobs/examples/obs-server-26.yml\
	logging/default.conf\
	logging/console.conf\
        logging/network-setup.conf

FULL_DIRS			= bin share/migrations share/fixtures public views
CONFIG_DIRS		= \
	etc/kanku/templates\
	etc/kanku/templates/cmd\
	etc/kanku/templates/cmd/setup\
	etc/kanku/templates/cmd/setup/etc\
	etc/kanku/templates/examples-vm/\
	etc/kanku/jobs\
	etc/kanku/jobs/examples\
	etc/kanku/logging
DOCDIR = $(DESTDIR)/usr/share/doc/packages/kanku/
PERL_CRITIC_READY := bin/*

all:

install: install_dirs install_full_dirs install_services install_docs configs
	install -m 644 ./dist/kanku.logrotate $(DESTDIR)/etc/logrotate.d/kanku-common
	install -m 644 dist/profile.d-kanku.sh $(DESTDIR)/etc/profile.d/kanku.sh
	install -m 644 dist/tmpfiles.d-kanku $(DESTDIR)/usr/lib/tmpfiles.d/kanku

configs:
	#
	for i in $(CONFIG_DIRS);do \
		mkdir -p $(DESTDIR)/$$i ; \
	done
	#
	for i in $(CONFIG_FILES);do \
		cp -av ./etc/$$i $(DESTDIR)/etc/kanku/$$i ;\
	done

install_full_dirs: lib
	install -m 755 bin/network-setup.pl $(DESTDIR)/usr/lib/kanku/network-setup.pl
	install -m 755 bin/kanku $(DESTDIR)/usr/bin/kanku
	install -m 755 bin/kanku-app.psgi $(DESTDIR)/usr/lib/kanku/kanku-app.psgi
	install -m 755 sbin/kanku-worker $(DESTDIR)/usr/sbin/kanku-worker
	install -m 755 sbin/kanku-dispatcher $(DESTDIR)/usr/sbin/kanku-dispatcher
	install -m 755 sbin/kanku-scheduler $(DESTDIR)/usr/sbin/kanku-scheduler
	install -m 755 sbin/kanku-triggerd $(DESTDIR)/usr/sbin/kanku-triggerd
	cp -av share/migrations $(DESTDIR)/usr/share/kanku/
	cp -av share/fixtures $(DESTDIR)/usr/share/kanku/
	cp -av views  $(DESTDIR)/usr/share/kanku/
	cp -av public $(DESTDIR)/usr/share/kanku/

lib:
	cp -av ./lib/ $(DESTDIR)/usr/lib/kanku/

install_dirs:
	install -m 755 -d $(DESTDIR)/etc/logrotate.d/
	install -m 755 -d $(DESTDIR)/etc/apache2/conf.d
	install -m 755 -d $(DESTDIR)/etc/profile.d
	install -m 755 -d $(DESTDIR)/etc/kanku
	install -m 755 -d $(DESTDIR)/usr/share/kanku
	install -m 755 -d $(DESTDIR)/usr/lib/kanku
	install -m 755 -d $(DESTDIR)/var/log/kanku
	install -m 755 -d $(DESTDIR)/run/kanku
	install -m 755 -d $(DESTDIR)/var/cache/kanku
	install -m 755 -d $(DESTDIR)/var/lib/kanku
	install -m 755 -d $(DESTDIR)/var/lib/kanku/db
	install -m 755 -d $(DESTDIR)/var/lib/kanku/sessions
	install -m 755 -d $(DESTDIR)/usr/lib/systemd/system
	install -m 755 -d $(DESTDIR)/usr/sbin
	install -m 755 -d $(DESTDIR)/usr/share/doc/packages/kanku/contrib/libvirt-configs

install_services: install_dirs
	install -m 644 ./dist/systemd/kanku-worker.service $(DESTDIR)/usr/lib/systemd/system/kanku-worker.service
	install -m 644 ./dist/systemd/kanku-scheduler.service $(DESTDIR)/usr/lib/systemd/system/kanku-scheduler.service
	install -m 644 ./dist/systemd/kanku-triggerd.service $(DESTDIR)/usr/lib/systemd/system/kanku-triggerd.service
	install -m 644 ./dist/systemd/kanku-web.service $(DESTDIR)/usr/lib/systemd/system/kanku-web.service
	install -m 644 ./dist/systemd/kanku-dispatcher.service $(DESTDIR)/usr/lib/systemd/system/kanku-dispatcher.service

install_docs:
	install -m 644 README.md $(DOCDIR)
	install -m 644 CONTRIBUTING.md $(DOCDIR)
	install -m 644 INSTALL.md $(DOCDIR)
	install -m 644 LICENSE $(DOCDIR)
	install -m 644 docs/Development.pod $(DOCDIR)/contrib/
	install -m 644 docs/README.apache-proxy.md $(DOCDIR)/contrib/
	install -m 644 docs/README.rabbitmq.md $(DOCDIR)/contrib/
	install -m 644 docs/README.setup-ovs.md $(DOCDIR)/contrib/
	install -m 644 docs/README.setup-worker.md $(DOCDIR)/contrib/

clean:
	rm -rf kanku-*.tar.xz

test:
	prove -Ilib -It/lib t/*.t

critic:
	perlcritic -brutal $(PERL_CRITIC_READY)

cover:
	PERL5LIB=lib:t/lib cover -test -ignore '(^\/usr|t\/)'

check: cover critic

.PHONY: dist install lib cover check test
