/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-17 21:37:11
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-21 18:28:35
 */
#include "include/flutter_qjs/flutter_qjs_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define FLUTTER_QJS_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_qjs_plugin_get_type(), \
                              FlutterQjsPlugin))

struct _FlutterQjsPlugin
{
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterQjsPlugin, flutter_qjs_plugin, g_object_get_type())

static void flutter_qjs_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(flutter_qjs_plugin_parent_class)->dispose(object);
}

static void flutter_qjs_plugin_class_init(FlutterQjsPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = flutter_qjs_plugin_dispose;
}

static void flutter_qjs_plugin_init(FlutterQjsPlugin *self) {}

void flutter_qjs_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
}
