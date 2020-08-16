package soko.ekibun.flutter_qjs

import androidx.annotation.Keep

import android.os.Handler
import io.flutter.plugin.common.MethodChannel

@Keep
class MethodChannelWrapper(private val handler: Handler, private val channel: MethodChannel) {
    fun invokeMethod(method: String, arguments: Any?, promise: Long) {
        handler.post {
            channel.invokeMethod(method, arguments, object : MethodChannel.Result {
                override fun notImplemented() {
                    JniBridge.instance.reject(promise, "notImplemented")
                }

                override fun error(error_code: String?, error_message: String?, error_data: Any?) {
                    JniBridge.instance.reject(promise, error_message ?: "undefined")
                }

                override fun success(data: Any?) {
                    JniBridge.instance.resolve(promise, data)
                }

            })
        }

    }
}