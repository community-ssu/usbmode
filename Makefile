all: libcpusbmode.so libusbmode-status-menu-item.so usbmode

install: all
	install -d "$(DESTDIR)/usr/bin/"
	install -d "$(DESTDIR)/usr/sbin/"
	install -d "$(DESTDIR)/etc/sudoers.d"
	install -d "$(DESTDIR)/usr/share/applications/hildon/"
	install -d "$(DESTDIR)/usr/share/applications/hildon-status-menu/"
	install -d "$(DESTDIR)/usr/share/applications/hildon-control-panel/"
	install -d "$(DESTDIR)/usr/lib/hildon-desktop/"
	install -d "$(DESTDIR)/usr/lib/hildon-control-panel/"
	install -m 755 usbmode "$(DESTDIR)/usr/bin/"
	install -m 755 usbmode.sh "$(DESTDIR)/usr/sbin/"
	install -m 644 usbmode.sudoers "$(DESTDIR)/etc/sudoers.d"
	install -m 644 usbmode.desktop "$(DESTDIR)/usr/share/applications/hildon/"
	install -m 644 usbmode-status-menu-item.desktop "$(DESTDIR)/usr/share/applications/hildon-status-menu/"
	install -m 644 cpusbmode.desktop "$(DESTDIR)/usr/share/applications/hildon-control-panel/"
	install -m 644 libusbmode-status-menu-item.so "$(DESTDIR)/usr/lib/hildon-desktop/"
	install -m 644 libcpusbmode.so "$(DESTDIR)/usr/lib/hildon-control-panel/"

uninstall:
	$(RM) "$(DESTDIR)/usr/bin/usbmode"
	$(RM) "$(DESTDIR)/usr/sbin/usbmode.sh"
	$(RM) "$(DESTDIR)/etc/sudoers.d/usbmode.sudoers"
	$(RM) "$(DESTDIR)/usr/share/applications/hildon/usbmode.desktop"
	$(RM) "$(DESTDIR)/usr/share/applications/hildon-status-menu/usbmode-status-menu-item.desktop"
	$(RM) "$(DESTDIR)/usr/share/applications/hildon-control-panel/cpusbmode.desktop"
	$(RM) "$(DESTDIR)/usr/lib/hildon-desktop/libusbmode-status-menu-item.so"
	$(RM) "$(DESTDIR)/usr/lib/hildon-control-panel/libcpusbmode.so"

clean:
	$(RM) libcpusbmode.so
	$(RM) libusbmode-status-menu-item.so
	$(RM) usbmode

libcpusbmode.so: cpusbmode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(shell pkg-config --cflags --libs hildon-control-panel hildon-1 libosso) -W -Wall -O2 -shared $^ -o $@

libusbmode-status-menu-item.so: usbmode-status-menu-item.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(shell pkg-config --cflags --libs libhildondesktop-1 hildon-1) -W -Wall -O2 -shared $^ -o $@

usbmode: usbmode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(shell pkg-config --cflags --libs hildon-1) -W -Wall -O2 $^ -o $@

.PHONY: all install uninstall clean
