package soko.ekibun.flutter_qjs

import androidx.annotation.Keep

import android.os.Handler
import io.flutter.plugin.common.MethodChannel.Result

@Keep
class ResultWrapper(private val handler: Handler, private val result: Result) {

  @Keep
  fun success(dat: String) {
    handler.post { result.success(dat) }
  }

  @Keep
  fun error(error_message: String) {
    handler.post { result.error("FlutterJSException", error_message, null) }
  }
}