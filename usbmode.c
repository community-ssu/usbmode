/*
    usbmode.c - Executable application for configuring USB mode
    Copyright (C) 2012  Pali Rohár <pali.rohar@gmail.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

*/

#include <dlfcn.h>

#include <gtk/gtk.h>
#include <hildon/hildon.h>

int main(int argc, char * argv[]) {

	void * handle;
	int (*execute)(void *, gpointer, gboolean);

	hildon_gtk_init(&argc, &argv);

	handle = dlopen("/usr/lib/hildon-control-panel/libcpusbmode.so", RTLD_LAZY);

	if ( ! handle )
		return 1;

	execute = dlsym(handle, "execute");

	if ( ! execute ) {
		dlclose(handle);
		return 1;
	}

	execute(NULL, NULL, TRUE);
	dlclose(handle);

	return 0;

}
