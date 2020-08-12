package soko.ekibun.flutter_qjs

import android.os.Handler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

/** FlutterQjsPlugin */
class FlutterQjsPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channelwrapper : MethodChannelWrapper
  private lateinit var channel : MethodChannel
  private var engine : JniBridge? = null
  private lateinit var applicationContext: android.content.Context
  private val handler by lazy { Handler() }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    val channel = MethodChannel(flutterPluginBinding.binaryMessenger, "soko.ekibun.flutter_qjs")
    channel.setMethodCallHandler(this)
    channelwrapper = MethodChannelWrapper(handler, channel)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "initEngine") {
      // engine = JsEngine(channel)
      engine = JniBridge()
      engine?.initEngine(channelwrapper)
      result.success(1)
    } else if (call.method == "evaluate") {
      val script: String = call.argument<String>("script")!!
      val name: String = call.argument<String>("name")!!
      engine?.evaluate(script, name, ResultWrapper(handler, result))
      // engine?.evaluate(script, result)
    } else if (call.method == "close") {
      // engine?.release()
      engine?.close()
      engine = null
      result.success(null)
    } else {
      result.notImplemented()
      result.success(null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
