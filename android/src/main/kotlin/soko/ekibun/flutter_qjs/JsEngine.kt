package soko.ekibun.flutter_qjs

// import android.util.Log
// import de.prosiebensat1digital.oasisjsbridge.*
import io.flutter.plugin.common.MethodChannel
// import kotlinx.coroutines.*

class JsEngine(private val channel: MethodChannel) {
//     private val jsBridge = JsBridge(JsBridgeConfig.bareConfig())

//     fun processPromiseQueue() {
//         JsBridge::class.java.getDeclaredMethod("processPromiseQueue").invoke(jsBridge)
//     }

//     private fun dartInteract(resolve: (String) -> Unit, reject: (String) -> Unit, method: String, args: String) {
//         println("dart: $method")
//         jsBridge.launch(Dispatchers.Main) {
//             channel.invokeMethod(method, args, object : MethodChannel.Result {
//                 override fun notImplemented() {
//                     println("dart error: notImplemented")
//                     jsBridge.launch(Dispatchers.Main) {
//                         reject("notImplemented")
//                         withContext(jsBridge.coroutineContext) {
//                             processPromiseQueue()
//                         }
//                     }
//                 }

//                 override fun error(error_code: String?, error_message: String?, error_details: Any?) {
//                     println("dart error: ${error_message ?: "undefined"}")
//                     jsBridge.launch(Dispatchers.Main) {
//                         reject(error_message ?: "undefined")
//                         withContext(jsBridge.coroutineContext) {
//                             processPromiseQueue()
//                         }
//                     }
//                 }

//                 override fun success(result: Any?) {
//                     println("dart success: $result")
//                     jsBridge.launch(Dispatchers.Main) {
//                         resolve(result.toString())
//                         withContext(jsBridge.coroutineContext) {
//                             processPromiseQueue()
//                         }
//                     }
//                 }
//             })
//         }
//     }

//     init {
// //        jsBridge.initEngine()
//         jsBridge.launch(Dispatchers.Main) {
//             JsValue.fromNativeFunction4(jsBridge, ::dartInteract).assignToGlobal("__DartImpl__invoke")
//             jsBridge.evaluateAsync<Deferred<String>>("""
//                 this.dart = (method, ...args) => new Promise((res, rej) =>
//                         this.__DartImpl__invoke((v) => res(JSON.parse(v)), rej, method, JSON.stringify(args)))
//             """).await().await()
//         }
//     }

//     fun eval(script: String, result: MethodChannel.Result) {
//         jsBridge.launch(Dispatchers.Main) {
//             try {
//                 var ret = jsBridge.evaluateAsync<Deferred<String>>(script).await().await()
//                 println(ret)
//                 result.success(ret)
//             } catch (e: Throwable) {
//                 e.printStackTrace()
//                 result.error("FlutterJSException", Log.getStackTraceString(e), null)
//             }
//         }

//     }

//     fun release() {
//         jsBridge.release()
//     }
}