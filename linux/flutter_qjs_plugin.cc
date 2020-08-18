/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-17 21:37:11
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-18 08:23:56
 */
#include "include/flutter_qjs/flutter_qjs_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include "dart_js_wrapper.hpp"

#define FLUTTER_QJS_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_qjs_plugin_get_type(), \
                              FlutterQjsPlugin))

struct _FlutterQjsPlugin
{
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterQjsPlugin, flutter_qjs_plugin, g_object_get_type())

g_autoptr(FlMethodChannel) channel = nullptr;

std::promise<qjs::JSFutureReturn> *invokeChannelMethod(std::string name, qjs::Value args, qjs::Engine *engine)
{
  auto promise = new std::promise<qjs::JSFutureReturn>();
  return promise;
}

// Called when a method call is received from Flutter.
static void flutter_qjs_plugin_handle_method_call(
    FlutterQjsPlugin *self,
    FlMethodCall *method_call)
{
  const gchar *method = fl_method_call_get_name(method_call);

  if (strcmp(method, "createEngine") == 0)
  {
    qjs::Engine *engine = new qjs::Engine(invokeChannelMethod);
    g_warning("engine %ld", engine);
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int((int64_t)engine)));
    fl_method_call_respond(method_call, response, nullptr);
    // g_autoptr(GError) error = nullptr;
    // if (!fl_method_call_respond(method_call, response, &error))
    //   g_warning("Failed to send method call response: %s", error->message);
  }
  else if (strcmp(method, "evaluate") == 0)
  {
    FlValue *args = fl_method_call_get_args(method_call);
    qjs::Engine *engine = (qjs::Engine *)fl_value_get_int(fl_value_lookup_string(args, "engine"));
    std::string script(fl_value_get_string(fl_value_lookup_string(args, "script")));
    std::string name(fl_value_get_string(fl_value_lookup_string(args, "name")));
    g_warning("engine %ld; script: %s; name: %s", (int64_t)engine, script.c_str(), name.c_str());
    auto pmethod_call = (FlMethodCall *)g_object_ref(method_call);
    engine->commit(qjs::EngineTask{
        [script, name](qjs::Context &ctx) {
          return ctx.eval(script, name.c_str(), JS_EVAL_TYPE_GLOBAL);
        },
        [pmethod_call](qjs::Value resolve) {
          g_warning("%s", fl_value_to_string(qjs::jsToDart(resolve)));
          g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(qjs::jsToDart(resolve)));
          fl_method_call_respond(pmethod_call, response, nullptr);
          g_object_unref(pmethod_call);
        },
        [pmethod_call](qjs::Value reject) {
          fl_method_call_respond_error(pmethod_call, "FlutterJSException", qjs::getStackTrack(reject).c_str(), nullptr, nullptr);
          g_object_unref(pmethod_call);
        }});
    // g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(args));
    // fl_method_call_respond(method_call, response, nullptr);
    // g_autoptr(GError) error = nullptr;
    // if (!fl_method_call_respond(method_call, response, &error))
    //   g_warning("Failed to send method call response: %s", error->message);
  }
  else
  {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
  }
}

static void flutter_qjs_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(flutter_qjs_plugin_parent_class)->dispose(object);
}

static void flutter_qjs_plugin_class_init(FlutterQjsPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = flutter_qjs_plugin_dispose;
}

static void flutter_qjs_plugin_init(FlutterQjsPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  FlutterQjsPlugin *plugin = FLUTTER_QJS_PLUGIN(user_data);
  flutter_qjs_plugin_handle_method_call(plugin, method_call);
}

void flutter_qjs_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  FlutterQjsPlugin *plugin = FLUTTER_QJS_PLUGIN(
      g_object_new(flutter_qjs_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "soko.ekibun.flutter_qjs",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
