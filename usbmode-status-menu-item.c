/*
    usbmode-status-menu.c - Status menu item plugin for configuring USB mode
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
#include <gconf/gconf-client.h>

#include "usbmode-status-menu-item.h"

HD_DEFINE_PLUGIN_MODULE(USBModeStatusMenuItem, usbmode_status_menu_item, HD_TYPE_STATUS_MENU_ITEM);

static void usbmode_status_menu_item_clicked(GObject * button G_GNUC_UNUSED, gpointer user_data G_GNUC_UNUSED) {

	void * handle;
	int (*execute)(void *, gpointer, gboolean);

	handle = dlopen("/usr/lib/hildon-control-panel/libcpusbmode.so", RTLD_LAZY);

	if ( ! handle )
		return;

	execute = dlsym(handle, "execute");

	if ( ! execute )
		return;

	execute(NULL, NULL, TRUE);
	dlclose(handle);

}

static void usbmode_status_menu_item_init(USBModeStatusMenuItem * plugin) {

	GtkWidget * button = hildon_button_new(HILDON_SIZE_FINGER_HEIGHT | HILDON_SIZE_AUTO_WIDTH, HILDON_BUTTON_ARRANGEMENT_VERTICAL);

	if ( ! button )
		return;

	hildon_button_set_style(HILDON_BUTTON(button), HILDON_BUTTON_STYLE_PICKER);
	hildon_button_set_image(HILDON_BUTTON(button), gtk_image_new_from_icon_name("statusarea_usb_active", GTK_ICON_SIZE_DIALOG));
	hildon_button_set_title(HILDON_BUTTON(button), "USB mode");
	gtk_button_set_alignment(GTK_BUTTON(button), 0, 0);
	g_signal_connect_after(G_OBJECT(button), "clicked", G_CALLBACK(usbmode_status_menu_item_clicked), plugin);

	gtk_container_add(GTK_CONTAINER(plugin), button);

}

static void usbmode_status_menu_item_finalize(GObject * object) {

	G_OBJECT_CLASS(usbmode_status_menu_item_parent_class)->finalize(object);

}

static void usbmode_status_menu_item_class_init(USBModeStatusMenuItemClass * klass) {

	GObjectClass * object_class = G_OBJECT_CLASS(klass);
	object_class->finalize = (GObjectFinalizeFunc)usbmode_status_menu_item_finalize;

}

static void usbmode_status_menu_item_class_finalize(USBModeStatusMenuItemClass * klass G_GNUC_UNUSED) {

}
