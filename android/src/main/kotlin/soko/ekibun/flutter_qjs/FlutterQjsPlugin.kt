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
  private lateinit var applicationContext: android.content.Context
  private val handler by lazy { Handler() }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "soko.ekibun.flutter_qjs")
    channel.setMethodCallHandler(this)
    channelwrapper = MethodChannelWrapper(handler, channel)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "createEngine") {
      val engine: Long = JniBridge.instance.createEngine(channelwrapper)
      println(engine)
      result.success(engine)
    } else if (call.method == "evaluate") {
      val engine: Long = call.argument<Long>("engine")!!
      val script: String = call.argument<String>("script")!!
      val name: String = call.argument<String>("name")!!
      JniBridge.instance.evaluate(engine, script, name, ResultWrapper(handler, result))
    } else if (call.method == "call") {
      val engine: Long = call.argument<Long>("engine")!!
      val function: Long = call.argument<Long>("function")!!
      val args: List<Any> = call.argument<List<Any>>("arguments")!!
      JniBridge.instance.call(engine, function, args, ResultWrapper(handler, result))
    } else if (call.method == "close") {
      val engine: Long = call.arguments<Long>()
      println(engine)
      JniBridge.instance.close(engine)
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
