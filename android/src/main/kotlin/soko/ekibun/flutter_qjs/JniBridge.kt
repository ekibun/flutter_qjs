package soko.ekibun.flutter_qjs

class JniBridge {
    companion object {
        // Used to load the 'native-lib' library on application startup.
        init {
            System.loadLibrary("libjsengine")
        }

        val instance by lazy { JniBridge() }
    }

    external fun initEngine(channel: MethodChannelWrapper): Int

    external fun evaluate(script: String, name: String, result: ResultWrapper)

    external fun close()

    external fun reject(promise: Long, reason: String)

    external fun resolve(promise: Long, data: Any?)
}