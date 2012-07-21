all: libcpusbmode.so

install: all
	install -d "$(DESTDIR)/usr/sbin/"
	install -d "$(DESTDIR)/etc/sudoers.d"
	install -d "$(DESTDIR)/usr/share/applications/hildon-control-panel/"
	install -d "$(DESTDIR)/usr/lib/hildon-control-panel/"
	install -m 755 usbmode.sh "$(DESTDIR)/usr/sbin/"
	install -m 644 usbmode.sudoers "$(DESTDIR)/etc/sudoers.d"
	install -m 644 cpusbmode.desktop "$(DESTDIR)/usr/share/applications/hildon-control-panel/"
	install -m 644 libcpusbmode.so "$(DESTDIR)/usr/lib/hildon-control-panel/"

uninstall:
	$(RM) "$(DESTDIR)/usr/sbin/usbmode.sh"
	$(RM) "$(DESTDIR)/etc/sudoers.d/usbmode.sudoers"
	$(RM) "$(DESTDIR)/usr/share/applications/hildon-control-panel/cpusbmode.desktop"
	$(RM) "$(DESTDIR)/usr/lib/hildon-control-panel/libcpusbmode.so"

clean:
	$(RM) libcpusbmode.so

libcpusbmode.so: cpusbmode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(shell pkg-config --cflags --libs hildon-control-panel hildon-1 libosso) -W -Wall -O2 -shared $^ -o $@

.PHONY: all install uninstall clean
