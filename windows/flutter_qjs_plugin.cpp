#include "include/flutter_qjs/flutter_qjs_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include "js_engine.hpp"

namespace
{

  class FlutterQjsPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    FlutterQjsPlugin();

    virtual ~FlutterQjsPlugin();

  private:
    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;

  // static
  void FlutterQjsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "soko.ekibun.flutter_qjs",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<FlutterQjsPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  FlutterQjsPlugin::FlutterQjsPlugin() {}

  FlutterQjsPlugin::~FlutterQjsPlugin() {}

  const flutter::EncodableValue &ValueOrNull(const flutter::EncodableMap &map, const char *key)
  {
    static flutter::EncodableValue null_value;
    auto it = map.find(flutter::EncodableValue(key));
    if (it == map.end())
    {
      return null_value;
    }
    return it->second;
  }

  qjs::Engine *engine = nullptr;

  void FlutterQjsPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    // Replace "getPlatformVersion" check with your plugin's method.
    // See:
    // https://github.com/flutter/engine/tree/master/shell/platform/common/cpp/client_wrapper/include/flutter
    // and
    // https://github.com/flutter/engine/tree/master/shell/platform/glfw/client_wrapper/include/flutter
    // for the relevant Flutter APIs.
    if (method_call.method_name().compare("initEngine") == 0)
    {
      engine = new qjs::Engine(channel);
      flutter::EncodableValue response((long)engine);
      result->Success(&response);
    }
    else if (method_call.method_name().compare("evaluate") == 0)
    {
      flutter::EncodableMap args = *((flutter::EncodableMap *)method_call.arguments());
      std::string script = std::get<std::string>(ValueOrNull(args, "script"));
      std::string name = std::get<std::string>(ValueOrNull(args, "name"));
      auto presult = result.release();
      engine->commit(qjs::EngineTask{
          script, name,
          [presult](std::string resolve) {
            flutter::EncodableValue response(resolve);
            presult->Success(&response);
          },
          [presult](std::string reject) {
            presult->Error("FlutterJSException", reject);
          }});
    }
    else if (method_call.method_name().compare("close") == 0)
    {
      delete engine;
      result->Success();
    }
    else
    {
      result->NotImplemented();
    }
  }

} // namespace

void FlutterQjsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  FlutterQjsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
