package soko.ekibun.flutter_qjs

import android.os.Handler
import io.flutter.embedding.engine.plugins.FlutterPlugin

/** FlutterQjsPlugin */
class FlutterQjsPlugin: FlutterPlugin {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
  }
}
