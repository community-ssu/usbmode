/*
    usbmode-status-menu.h - Status menu item plugin for configuring USB mode
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

#ifndef __USBMODE_STATUS_MENU_ITEM_H__
#define __USBMODE_STATUS_MENU_ITEM_H__

#include <glib.h>
#include <glib-object.h>
#include <libhildondesktop/libhildondesktop.h>

G_BEGIN_DECLS

#define USBMODE_TYPE_STATUS_MENU_ITEM		(usbmode_status_menu_item_get_type())
#define USBMODE_STATUS_MENU_ITEM(obj)		(G_TYPE_CHECK_INSTANCE_CAST((obj), USBMODE_TYPE_STATUS_MENU_ITEM, USBModeStatusMenuItem))
#define USBMODE_IS_STATUS_MENU_ITEM(obj)		(G_TYPE_CHECK_INSTANCE_TYPE((obj), USBMODE_TYPE_STATUS_MENU_ITEM))
#define USBMODE_STATUS_MENU_ITEM_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST((klass), USBMODE_TYPE_STATUS_MENU_ITEM, USBModeStatusMenuItemClass))
#define USBMODE_IS_STATUS_MENU_ITEM_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE((klass), USBMODE_TYPE_STATUS_MENU_ITEM))
#define USBMODE_STATUS_MENU_ITEM_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS((obj), USBMODE_TYPE_STATUS_MENU_ITEM, USBModeStatusMenuItemClass))

typedef struct _USBModeStatusMenuItem		USBModeStatusMenuItem;
typedef struct _USBModeStatusMenuItemClass	USBModeStatusMenuItemClass;
typedef struct _USBModeStatusMenuItemPrivate	USBModeStatusMenuItemPrivate;

struct _USBModeStatusMenuItem {
	HDStatusMenuItem parent_instance;
	USBModeStatusMenuItemPrivate * priv;
};

struct _USBModeStatusMenuItemClass {
	HDStatusMenuItemClass parent_class;
};

GType usbmode_status_menu_item_get_type(void);

G_END_DECLS

#endif /* __USBMODE_STATUS_MENU_ITEM_H__ */
