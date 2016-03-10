DESTDIR				=	$(DESTDIR)
PREFIX				=	/opt/kanku
VERSION				=	$(shell grep VERSION lib/Kanku.pm |perl -p -e "s/.*'([\d.]+)'.*/\$$1/")
CONFIG_FILES 	= templates/cmd/init.tt2 templates/obs-server-26.tt2 templates/sles11sp3.tt2 templates/obs-server.tt2 console-log.conf config.yml.template jobs/obs-server.yml.template jobs/sles11sp3.yml.template jobs/obs-server-26.yml.template log4perl.conf templates/cmd/setup.config.yml.tt2
FULL_DIRS			= bin lib share/migrations share/fixtures public
CONFIG_DIRS		= etc etc/templates etc/templates/cmd etc/jobs

all:

install:
	install -m 755 -d $(DESTDIR)$(PREFIX)
	install -m 755 -d $(DESTDIR)$(PREFIX)/etc
	install -m 755 -d $(DESTDIR)$(PREFIX)/var/log
	install -m 755 -d $(DESTDIR)$(PREFIX)/share
	install -m 755 -d $(DESTDIR)/etc/sudoers.d/
	install -m 755 -d $(DESTDIR)/etc/apache2/conf.d
	install -m 755 -d $(DESTDIR)/etc/profile.d
	install -m 644 ./dist/sudoers.d.kanku $(DESTDIR)/etc/sudoers.d/kanku
	install -m 644 dist/kanku.conf.mod_proxy $(DESTDIR)/etc/apache2/conf.d/kanku.conf
	install -m 644 dist/profile.d-kanku.sh $(DESTDIR)/etc/profile.d/kanku.sh
	#
	for i in $(CONFIG_DIRS);do \
		mkdir -p $(DESTDIR)$(PREFIX)/$$i ; \
	done
	#
	for i in $(CONFIG_FILES);do \
		cp -av ./etc/$$i $(DESTDIR)$(PREFIX)/etc/$$i ;\
	done
	#
	for i in $(FULL_DIRS) ;do \
		cp -av ./$$i $(DESTDIR)$(PREFIX)/$$i ;\
	done

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

.PHONY: dist install
