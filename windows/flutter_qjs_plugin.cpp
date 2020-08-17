#include "include/flutter_qjs/flutter_qjs_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/method_result_functions.h>

#include "dart_js_wrapper.hpp"

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
  std::promise<qjs::JSFutureReturn> *invokeChannelMethod(std::string name, qjs::Value args, qjs::Engine *engine)
  {
    auto promise = new std::promise<qjs::JSFutureReturn>();
    auto map = new flutter::EncodableMap();
    (*map)[std::string("engine")] = (int64_t)engine;
    (*map)[std::string("args")] = qjs::jsToDart(args, std::unordered_map<qjs::Value, flutter::EncodableValue>());
    channel->InvokeMethod(
        name,
        std::make_unique<flutter::EncodableValue>(*map),
        std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
            (flutter::ResultHandlerSuccess<flutter::EncodableValue>)[promise](
                const flutter::EncodableValue *result) {
              promise->set_value((qjs::JSFutureReturn)[result = result ? *result : flutter::EncodableValue()](qjs::JSContext * ctx) {
                qjs::JSValue *ret = new qjs::JSValue{qjs::dartToJs(ctx, result)};
                return qjs::JSOSFutureArgv{1, ret};
              });
            },
            (flutter::ResultHandlerError<flutter::EncodableValue>)[promise](
                const std::string &error_code,
                const std::string &error_message,
                const flutter::EncodableValue *error_details) {
              promise->set_value((qjs::JSFutureReturn)[error_message](qjs::JSContext * ctx) {
                qjs::JSValue *ret = new qjs::JSValue{JS_NewString(ctx, error_message.c_str())};
                return qjs::JSOSFutureArgv{-1, ret};
              });
            },
            (flutter::ResultHandlerNotImplemented<flutter::EncodableValue>)[promise]() {
              promise->set_value((qjs::JSFutureReturn)[](qjs::JSContext * ctx) {
                qjs::JSValue *ret = new qjs::JSValue{JS_NewString(ctx, "NotImplemented")};
                return qjs::JSOSFutureArgv{-1, ret};
              });
            }));
    return promise;
  }

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
    if (method_call.method_name().compare("createEngine") == 0)
    {
      qjs::Engine *engine = new qjs::Engine(invokeChannelMethod);
      flutter::EncodableValue response = (int64_t)engine;
      result->Success(&response);
    }
    else if (method_call.method_name().compare("evaluate") == 0)
    {
      flutter::EncodableMap args = *std::get_if<flutter::EncodableMap>(method_call.arguments());
      qjs::Engine *engine = (qjs::Engine *)std::get<int64_t>(ValueOrNull(args, "engine"));
      std::string script = std::get<std::string>(ValueOrNull(args, "script"));
      std::string name = std::get<std::string>(ValueOrNull(args, "name"));
      auto presult = result.release();
      engine->commit(qjs::EngineTask{
          [script, name](qjs::Context &ctx) {
            return ctx.eval(script, name.c_str(), JS_EVAL_TYPE_GLOBAL);
          },
          [presult](qjs::Value resolve) {
            flutter::EncodableValue response = qjs::jsToDart(resolve);
            presult->Success(&response);
            delete presult;
          },
          [presult](qjs::Value reject) {
            presult->Error("FlutterJSException", qjs::getStackTrack(reject));
            delete presult;
          }});
    }
    else if (method_call.method_name().compare("call") == 0)
    {
      flutter::EncodableMap args = *std::get_if<flutter::EncodableMap>(method_call.arguments());
      qjs::Engine *engine = (qjs::Engine *)std::get<int64_t>(ValueOrNull(args, "engine"));
      qjs::JSValue *function = (qjs::JSValue *)std::get<int64_t>(ValueOrNull(args, "function"));
      flutter::EncodableList arguments = std::get<flutter::EncodableList>(ValueOrNull(args, "arguments"));
      auto presult = result.release();
      engine->commit(qjs::EngineTask{
          [function, arguments](qjs::Context &ctx) {
            size_t argscount = arguments.size();
            qjs::JSValue *callargs = new qjs::JSValue[argscount];
            for (size_t i = 0; i < argscount; i++)
            {
              callargs[i] = qjs::dartToJs(ctx.ctx, arguments[i]);
            }
            qjs::JSValue ret = JS_Call(ctx.ctx, *function, qjs::JSValue{qjs::JSValueUnion{0}, qjs::JS_TAG_UNDEFINED}, (int)argscount, callargs);
            qjs::JS_FreeValue(ctx.ctx, *function);
            if (qjs::JS_IsException(ret))
              throw qjs::exception{};
            return qjs::Value{ctx.ctx, ret};
          },
          [presult](qjs::Value resolve) {
            flutter::EncodableValue response = qjs::jsToDart(resolve);
            presult->Success(&response);
          },
          [presult](qjs::Value reject) {
            presult->Error("FlutterJSException", qjs::getStackTrack(reject));
          }});
    }
    else if (method_call.method_name().compare("close") == 0)
    {
      qjs::Engine *engine = (qjs::Engine *)*std::get_if<int64_t>(method_call.arguments());
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
