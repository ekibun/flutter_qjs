package soko.ekibun.flutter_qjs

class JniBridge {
    companion object {
        // Used to load the 'native-lib' library on application startup.
        init {
            System.loadLibrary("libjsengine")
        }

        val instance by lazy { JniBridge() }
    }

    external fun createEngine(channel: MethodChannelWrapper): Long

    external fun evaluate(engine: Long, script: String, name: String, result: ResultWrapper)

    external fun close(engine: Long)

    external fun call(engine: Long, function: Long, args: List<Any>, result: ResultWrapper)

    external fun reject(promise: Long, reason: String)

    external fun resolve(promise: Long, data: Any?)
}