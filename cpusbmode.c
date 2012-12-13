/*
    cpusbmode.c - Control panel plugin for script usbmode.sh
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

#include <string.h>

#include <gtk/gtk.h>
#include <hildon/hildon.h>
#include <hildon-cp-plugin/hildon-cp-plugin-interface.h>

enum usbmode {
	MODE_PERIPHERAL,
	MODE_HOST,
	MODE_HOSTC,
};

static GtkWidget * peripheral;
static GtkWidget * host;
static GtkWidget * hostc;
static int id = -1;

static int usbmode_check(void) {

	int ret = 1;
	char * args[] = { "sudo", "/usr/sbin/usbmode.sh", "check", NULL };

	g_spawn_sync(NULL, args, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, NULL, NULL, &ret, NULL);

	if ( ret == 0 )
		return 1;
	else
		return 0;

}

static enum usbmode usbmode_state(void) {

	char * args[] = { "sudo", "/usr/sbin/usbmode.sh", "state", NULL };
	char * buf = NULL;
	enum usbmode mode;

	if ( ! g_spawn_sync(NULL, args, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, &buf, NULL, NULL, NULL) )
		return MODE_PERIPHERAL;

	if ( ! buf )
		return MODE_PERIPHERAL;

	if ( ( strstr(buf, "host with boost") ) )
		mode = MODE_HOST;
	else if ( ( strstr(buf, "host with charging") ) )
		mode = MODE_HOSTC;
	else
		mode = MODE_PERIPHERAL;

	g_free(buf);

	return mode;

}

static GPid usbmode_set_start(enum usbmode mode) {

	GPid pid = -1;
	char * args[] = { "sudo", "/usr/sbin/usbmode.sh", NULL, NULL };

	switch ( mode ) {

		case MODE_PERIPHERAL:
			args[2] = "peripheral";
			break;

		case MODE_HOST:
			args[2] = "host";
			break;

		case MODE_HOSTC:
			args[2] = "hostc";
			break;

	}

	if ( ! g_spawn_async(NULL, args, NULL, G_SPAWN_DO_NOT_REAP_CHILD | G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL | G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, &pid, NULL) )
		return -1;

	return pid;

}

static void update(void) {

	enum usbmode mode = usbmode_state();
	int old_id = id;

	if ( old_id < 0 )
		id = 1;

	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(peripheral), FALSE);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(host), FALSE);
	gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(hostc), FALSE);

	switch ( mode ) {

		case MODE_PERIPHERAL:
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(peripheral), TRUE);
			break;

		case MODE_HOST:
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(host), TRUE);
			break;

		case MODE_HOSTC:
			gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(hostc), TRUE);
			break;

	}

	if ( old_id < 0 )
		id = old_id;

}

static gboolean bar_pulse(gpointer user_data) {

	gtk_progress_bar_pulse(GTK_PROGRESS_BAR(user_data));
	return TRUE;

}

static void callback_finish(GPid pid, int status G_GNUC_UNUSED, gpointer user_data) {

	GtkWidget * dialog = NULL;

	if ( user_data )
		dialog = GTK_WIDGET(user_data);

	if ( pid > 0 )
		g_spawn_close_pid(pid);

	if ( id >= 0 )
		g_source_remove(id);

	if ( dialog )
		gtk_widget_destroy(dialog);

	update();

	id = -1;

}

static void callback(GObject * object, gpointer user_data) {

	GtkWindow * window = NULL;
	GtkWidget * button = GTK_WIDGET(object);
	GtkWidget * dialog;
	GtkWidget * box;
	GtkWidget * bar;
	char * text;
	enum usbmode mode;
	GPid pid;

	if ( id >= 0 )
		return;

	if ( button == peripheral )
		mode = MODE_PERIPHERAL;
	else if ( button == host )
		mode = MODE_HOST;
	else if ( button == hostc )
		mode = MODE_HOSTC;
	else
		return;

	if ( user_data )
		window = GTK_WINDOW(user_data);

	dialog = gtk_dialog_new();

	if ( ! dialog )
		return;

	gtk_window_set_title(GTK_WINDOW(dialog), "USB mode");
	gtk_window_set_modal(GTK_WINDOW(dialog), FALSE);

	box = gtk_vbox_new(FALSE, HILDON_MARGIN_DOUBLE);

	if ( ! box ) {
		gtk_widget_destroy(dialog);
		return;
	}

	gtk_container_add(GTK_CONTAINER(GTK_DIALOG(dialog)->vbox), box);

	bar = gtk_progress_bar_new();

	if ( ! bar ) {
		gtk_widget_destroy(dialog);
		return;
	}

	g_object_set(G_OBJECT(bar), "text-xalign", 0.5, NULL);
	gtk_box_pack_start(GTK_BOX(box), bar, FALSE, FALSE, 0);

	text = g_strdup_printf("Setting USB mode to: %s", gtk_button_get_label(GTK_BUTTON(button)));

	if ( ! text ) {
		gtk_widget_destroy(dialog);
		return;
	}

	gtk_progress_bar_set_text(GTK_PROGRESS_BAR(bar), text);
	g_free(text);

	id = g_timeout_add(500, bar_pulse, bar);

	if ( id < 0 ) {
		gtk_widget_destroy(dialog);
		return;
	}

	gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_CANCEL);
	gtk_widget_hide(GTK_DIALOG(dialog)->action_area);

	gtk_window_set_transient_for(GTK_WINDOW(dialog), window);
	gtk_widget_show_all(dialog);

	pid = usbmode_set_start(mode);

	if ( pid > 0 )
		g_child_watch_add(pid, callback_finish, dialog);
	else
		callback_finish(0, 0, dialog);

}

osso_return_t execute(osso_context_t * osso G_GNUC_UNUSED, gpointer user_data, gboolean user_activated G_GNUC_UNUSED) {

	GtkWindow * window = NULL;
	GtkWidget * dialog;
	GtkWidget * box;

	if ( user_data )
		window = GTK_WINDOW(user_data);

	if ( ! usbmode_check() ) {

		dialog = gtk_message_dialog_new(window, GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, "Error: Setting USB mode is not supported!");

		if ( ! dialog )
			return OSSO_ERROR;

		gtk_window_set_title(GTK_WINDOW(dialog), "USB mode");
		gtk_window_set_skip_pager_hint(GTK_WINDOW(dialog), 0);
		gtk_window_set_skip_taskbar_hint(GTK_WINDOW(dialog), 0);
		gtk_label_set_selectable(GTK_LABEL(GTK_MESSAGE_DIALOG(dialog)->label), 0);
		gtk_dialog_run(GTK_DIALOG(dialog));
		gtk_widget_destroy(dialog);

		return OSSO_ERROR;

	}

	dialog = gtk_dialog_new_with_buttons("USB mode", window, GTK_DIALOG_MODAL | GTK_DIALOG_NO_SEPARATOR, "Done", GTK_RESPONSE_OK, NULL);

	if ( ! dialog )
		return OSSO_ERROR;

	hildon_gtk_window_set_portrait_flags(GTK_WINDOW(dialog), HILDON_PORTRAIT_MODE_SUPPORT);

	box = gtk_vbox_new(TRUE, 0);

	if ( ! box ) {
		gtk_widget_destroy(dialog);
		return OSSO_ERROR;
	}

	gtk_box_pack_start(GTK_BOX(GTK_DIALOG(dialog)->vbox), box, TRUE, TRUE, 0);

	peripheral = hildon_gtk_toggle_button_new(HILDON_SIZE_FINGER_HEIGHT);

	if ( ! peripheral ) {
		gtk_widget_destroy(dialog);
		return OSSO_ERROR;
	}

	gtk_container_add(GTK_CONTAINER(box), peripheral);

	host = hildon_gtk_toggle_button_new(HILDON_SIZE_FINGER_HEIGHT);

	if ( ! host ) {
		gtk_widget_destroy(dialog);
		return OSSO_ERROR;
	}

	gtk_container_add(GTK_CONTAINER(box), host);

	hostc = hildon_gtk_toggle_button_new(HILDON_SIZE_FINGER_HEIGHT);

	if ( ! hostc ) {
		gtk_widget_destroy(dialog);
		return OSSO_ERROR;
	}

	gtk_container_add(GTK_CONTAINER(box), hostc);

	gtk_button_set_label(GTK_BUTTON(peripheral), "USB peripheral mode");
	gtk_button_set_label(GTK_BUTTON(host), "USB host mode (with boost)");
	gtk_button_set_label(GTK_BUTTON(hostc), "USB host mode (with charging)");

	g_signal_connect(peripheral, "toggled", G_CALLBACK(callback), dialog);
	g_signal_connect(host, "toggled", G_CALLBACK(callback), dialog);
	g_signal_connect(hostc, "toggled", G_CALLBACK(callback), dialog);

	update();

	gtk_widget_show_all(dialog);
	gtk_dialog_run(GTK_DIALOG(dialog));
	gtk_widget_destroy(GTK_WIDGET(dialog));

	return OSSO_OK;

}

osso_return_t save_state(osso_context_t * osso G_GNUC_UNUSED, gpointer user_data G_GNUC_UNUSED) {

	return OSSO_OK;

}
