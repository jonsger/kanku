PREFIX				=	/opt/kanku
VERSION				=	$(shell grep VERSION lib/Kanku.pm |perl -p -e "s/.*'([\d.]+)'.*/\$$1/")
CONFIG_FILES = \
	templates/cmd/init.tt2\
	templates/cmd/setup/config.yml.tt2\
	templates/cmd/setup/kanku.conf.mod_perl.tt2\
	templates/cmd/setup/kanku.conf.mod_proxy.tt2\
	templates/cmd/setup/openssl.cnf.tt2\
	templates/cmd/setup/etc/config.yml.tt2\
	templates/cmd/setup/net-default.xml.tt2\
	templates/cmd/setup/net-kanku-ovs.xml.tt2\
        templates/cmd/setup/pool-default.xml\
        templates/cmd/setup/rabbitmq.config.tt2\
	templates/examples-vm/obs-server-26.tt2\
	templates/examples-vm/sles11sp3.tt2\
	templates/examples-vm/obs-server.tt2\
	console-log.conf\
	jobs/examples/obs-server.yml\
	jobs/examples/sles11sp3.yml\
	jobs/examples/obs-server-26.yml\
	log4perl.conf\
	kanku-network-setup-logging.conf

FULL_DIRS			= bin share/migrations share/fixtures public views
CONFIG_DIRS		= \
	etc\
	etc/templates\
	etc/templates/cmd\
	etc/templates/cmd/setup\
	etc/templates/cmd/setup/etc\
	etc/templates/examples-vm/\
	etc/jobs\
	etc/jobs/examples
DOCDIR = $(DESTDIR)/usr/share/doc/packages/kanku/
PERL_CRITIC_READY := bin/*

all:

install: install_dirs install_full_dirs install_services install_docs
	install -m 644 ./dist/kanku.logrotate $(DESTDIR)/etc/logrotate.d/kanku-common
	install -m 644 dist/profile.d-kanku.sh $(DESTDIR)/etc/profile.d/kanku.sh
	#
	for i in $(CONFIG_DIRS);do \
		mkdir -p $(DESTDIR)$(PREFIX)/$$i ; \
	done
	#
	for i in $(CONFIG_FILES);do \
		cp -av ./etc/$$i $(DESTDIR)$(PREFIX)/etc/$$i ;\
	done

install_full_dirs: lib
	#
	for i in $(FULL_DIRS) ;do \
		cp -av ./$$i `dirname $(DESTDIR)$(PREFIX)/$$i` ;\
	done

lib:
	cp -av ./lib $(DESTDIR)$(PREFIX)

install_dirs:
	install -m 755 -d $(DESTDIR)$(PREFIX)
	install -m 755 -d $(DESTDIR)$(PREFIX)/etc
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/log
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/cache
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/run
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/db
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/sessions
	install -m 755 -d $(DESTDIR)$(PREFIX)/share
	install -m 755 -d $(DESTDIR)/etc/logrotate.d/
	install -m 755 -d $(DESTDIR)/etc/apache2/conf.d
	install -m 755 -d $(DESTDIR)/etc/profile.d
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

dist_dirs:
	mkdir kanku-$(VERSION)
	mkdir kanku-$(VERSION)/share
	for i in $(CONFIG_DIRS);do \
		mkdir -p kanku-$(VERSION)/$$i ;\
	done

dist_config_files: dist_dirs
	for i in $(CONFIG_FILES);do \
		cp -av ./etc/$$i kanku-$(VERSION)/etc/$$i ;\
	done

dist: dist_config_files
	cp -av etc bin lib var public Makefile dist README.md TODO kanku-$(VERSION)
	cp -av share/fixtures share/migrations kanku-$(VERSION)/share/
	tar cvJf kanku-$(VERSION).tar.xz kanku-$(VERSION)
	rm -rf kanku-$(VERSION)

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
