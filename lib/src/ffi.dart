/*
 * @Description: ffi
 * @Author: ekibun
 * @Date: 2020-09-19 10:29:04
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:35
 */
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

abstract class JSRef {
  int _refCount = 0;
  void dup() {
    _refCount++;
  }

  void free() {
    _refCount--;
    if (_refCount < 0) destroy();
  }

  void destroy();

  static void freeRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.free());
  }

  static void dupRecursive(dynamic obj) {
    _callRecursive(obj, (ref) => ref.dup());
  }

  static void _callRecursive(
    dynamic obj,
    void Function(JSRef) cb, [
    Set cache,
  ]) {
    if (obj == null) return;
    if (cache == null) cache = Set();
    if (cache.contains(obj)) return;
    if (obj is List) {
      cache.add(obj);
      List.from(obj).forEach((e) => _callRecursive(e, cb, cache));
    }
    if (obj is Map) {
      cache.add(obj);
      obj.values.toList().forEach((e) => _callRecursive(e, cb, cache));
    }
    if (obj is JSRef) {
      cb(obj);
    }
  }
}

abstract class JSRefLeakable {}

class JSEvalFlag {
  static const GLOBAL = 0 << 0;
  static const MODULE = 1 << 0;
}

class JSChannelType {
  static const METHON = 0;
  static const MODULE = 1;
  static const PROMISE_TRACK = 2;
  static const FREE_OBJECT = 3;
}

class JSProp {
  static const CONFIGURABLE = (1 << 0);
  static const WRITABLE = (1 << 1);
  static const ENUMERABLE = (1 << 2);
  static const C_W_E = (CONFIGURABLE | WRITABLE | ENUMERABLE);
}

class JSTag {
  static const FIRST = -11; /* first negative tag */
  static const BIG_DECIMAL = -11;
  static const BIG_INT = -10;
  static const BIG_FLOAT = -9;
  static const SYMBOL = -8;
  static const STRING = -7;
  static const MODULE = -3; /* used internally */
  static const FUNCTION_BYTECODE = -2; /* used internally */
  static const OBJECT = -1;

  static const INT = 0;
  static const BOOL = 1;
  static const NULL = 2;
  static const UNDEFINED = 3;
  static const UNINITIALIZED = 4;
  static const CATCH_OFFSET = 5;
  static const EXCEPTION = 6;
  static const FLOAT64 = 7;
}

final DynamicLibrary _qjsLib = Platform.environment['FLUTTER_TEST'] == 'true'
    ? (Platform.isWindows
        ? DynamicLibrary.open('test/build/Debug/ffiquickjs.dll')
        : Platform.isMacOS
            ? DynamicLibrary.open('test/build/libffiquickjs.dylib')
            : DynamicLibrary.open('test/build/libffiquickjs.so'))
    : (Platform.isWindows
        ? DynamicLibrary.open('flutter_qjs_plugin.dll')
        : Platform.isAndroid
            ? DynamicLibrary.open('libqjs.so')
            : DynamicLibrary.process());

/// DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
final Pointer Function(
  Pointer ctx,
  Pointer obj,
) jsThrow = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>('jsThrow')
    .asFunction();

/// JSValue *jsEXCEPTION()
final Pointer Function() jsEXCEPTION = _qjsLib
    .lookup<NativeFunction<Pointer Function()>>('jsEXCEPTION')
    .asFunction();

/// JSValue *jsUNDEFINED()
final Pointer Function() jsUNDEFINED = _qjsLib
    .lookup<NativeFunction<Pointer Function()>>('jsUNDEFINED')
    .asFunction();

typedef _JSChannel = Pointer Function(Pointer ctx, int method, Pointer argv);
typedef _JSChannelNative = Pointer Function(
    Pointer ctx, IntPtr method, Pointer argv);

/// JSRuntime *jsNewRuntime(JSChannel channel)
final Pointer Function(
  Pointer<NativeFunction<_JSChannelNative>>,
) _jsNewRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsNewRuntime')
    .asFunction();

class _RuntimeOpaque {
  _JSChannel _channel;
  List<JSRef> _ref = [];
  ReceivePort _port;
  int _dartObjectClassId;
  get dartObjectClassId => _dartObjectClassId;

  void addRef(JSRef ref) => _ref.add(ref);

  bool removeRef(JSRef ref) => _ref.remove(ref);

  JSRef getRef(bool Function(JSRef ref) test) {
    return _ref.firstWhere(test, orElse: () => null);
  }
}

final Map<Pointer, _RuntimeOpaque> runtimeOpaques = Map();

Pointer channelDispacher(Pointer ctx, int type, Pointer argv) {
  Pointer rt = type == JSChannelType.FREE_OBJECT ? ctx : jsGetRuntime(ctx);
  return runtimeOpaques[rt]?._channel(ctx, type, argv);
}

Pointer jsNewRuntime(
  _JSChannel callback,
  ReceivePort port,
) {
  final rt = _jsNewRuntime(Pointer.fromFunction(channelDispacher));
  runtimeOpaques[rt] = _RuntimeOpaque()
    .._channel = callback
    .._port = port;
  return rt;
}

/// DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
final void Function(
  Pointer,
  int,
) jsSetMaxStackSize = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      IntPtr,
    )>>('jsSetMaxStackSize')
    .asFunction();

/// void jsFreeRuntime(JSRuntime *rt)
final void Function(
  Pointer,
) _jsFreeRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
    )>>('jsFreeRuntime')
    .asFunction();

void jsFreeRuntime(
  Pointer rt,
) {
  final referenceleak = <String>[];
  while (true) {
    final ref = runtimeOpaques[rt]
        ?._ref
        ?.firstWhere((ref) => ref is JSRefLeakable, orElse: () => null);
    if (ref == null) break;
    ref.destroy();
    runtimeOpaques[rt]?._ref?.remove(ref);
  }
  while (0 < runtimeOpaques[rt]?._ref?.length ?? 0) {
    final ref = runtimeOpaques[rt]?._ref?.first;
    final objStrs = ref.toString().split('\n');
    final objStr = objStrs.length > 0 ? objStrs[0] + " ..." : objStrs[0];
    referenceleak.add(
        "  ${identityHashCode(ref)}\t${ref._refCount + 1}\t${ref.runtimeType.toString()}\t$objStr");
    ref.destroy();
  }
  _jsFreeRuntime(rt);
  if (referenceleak.length > 0) {
    throw ('reference leak:\n    ADDR\tREF\tTYPE\tPROP\n' +
        referenceleak.join('\n'));
  }
}

/// JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
final Pointer Function(
  Pointer ctx,
  Pointer funcData,
) jsNewCFunction = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>('jsNewCFunction')
    .asFunction();

/// JSContext *jsNewContext(JSRuntime *rt)
final Pointer Function(
  Pointer rt,
) _jsNewContext = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsNewContext')
    .asFunction();

Pointer jsNewContext(Pointer rt) {
  final ctx = _jsNewContext(rt);
  final runtimeOpaque = runtimeOpaques[rt];
  if (runtimeOpaque == null) throw Exception('Runtime has been released!');
  runtimeOpaque._dartObjectClassId = jsNewClass(ctx, 'DartObject');
  return ctx;
}

/// void jsFreeContext(JSContext *ctx)
final void Function(
  Pointer,
) jsFreeContext = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
    )>>('jsFreeContext')
    .asFunction();

/// JSRuntime *jsGetRuntime(JSContext *ctx)
final Pointer Function(
  Pointer,
) jsGetRuntime = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsGetRuntime')
    .asFunction();

/// JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
final Pointer Function(
  Pointer ctx,
  Pointer<Utf8> input,
  int inputLen,
  Pointer<Utf8> filename,
  int evalFlags,
) _jsEval = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Utf8>,
      IntPtr,
      Pointer<Utf8>,
      Int32,
    )>>('jsEval')
    .asFunction();

Pointer jsEval(
  Pointer ctx,
  String input,
  String filename,
  int evalFlags,
) {
  final utf8input = input.toNativeUtf8();
  final utf8filename = filename.toNativeUtf8();
  final val = _jsEval(
    ctx,
    utf8input,
    utf8input.length,
    utf8filename,
    evalFlags,
  );
  malloc.free(utf8input);
  malloc.free(utf8filename);
  runtimeOpaques[jsGetRuntime(ctx)]._port.sendPort.send(#eval);
  return val;
}

/// DLLEXPORT int32_t jsValueGetTag(JSValue *val)
final int Function(
  Pointer val,
) jsValueGetTag = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>('jsValueGetTag')
    .asFunction();

/// void *jsValueGetPtr(JSValue *val)
final Pointer Function(
  Pointer val,
) jsValueGetPtr = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsValueGetPtr')
    .asFunction();

/// DLLEXPORT bool jsTagIsFloat64(int32_t tag)
final int Function(
  int val,
) jsTagIsFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Int32,
    )>>('jsTagIsFloat64')
    .asFunction();

/// JSValue *jsNewBool(JSContext *ctx, int val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsNewBool = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Int32,
    )>>('jsNewBool')
    .asFunction();

/// JSValue *jsNewInt64(JSContext *ctx, int64_t val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsNewInt64 = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Int64,
    )>>('jsNewInt64')
    .asFunction();

/// JSValue *jsNewFloat64(JSContext *ctx, double val)
final Pointer Function(
  Pointer ctx,
  double val,
) jsNewFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Double,
    )>>('jsNewFloat64')
    .asFunction();

/// JSValue *jsNewString(JSContext *ctx, const char *str)
final Pointer Function(
  Pointer ctx,
  Pointer<Utf8> str,
) _jsNewString = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Utf8>,
    )>>('jsNewString')
    .asFunction();

Pointer jsNewString(
  Pointer ctx,
  String str,
) {
  final utf8str = str.toNativeUtf8();
  final jsStr = _jsNewString(ctx, utf8str);
  malloc.free(utf8str);
  return jsStr;
}

/// JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
final Pointer Function(
  Pointer ctx,
  Pointer<Uint8> buf,
  int len,
) jsNewArrayBufferCopy = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Uint8>,
      IntPtr,
    )>>('jsNewArrayBufferCopy')
    .asFunction();

/// JSValue *jsNewArray(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsNewArray = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsNewArray')
    .asFunction();

/// JSValue *jsNewObject(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsNewObject = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsNewObject')
    .asFunction();

/// void jsFreeValue(JSContext *ctx, JSValue *val, int32_t free)
final void Function(
  Pointer ctx,
  Pointer val,
  int free,
) _jsFreeValue = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer,
      Int32,
    )>>('jsFreeValue')
    .asFunction();

void jsFreeValue(
  Pointer ctx,
  Pointer val, {
  bool free = true,
}) {
  _jsFreeValue(ctx, val, free ? 1 : 0);
}

/// void jsFreeValue(JSRuntime *rt, JSValue *val, int32_t free)
final void Function(
  Pointer rt,
  Pointer val,
  int free,
) _jsFreeValueRT = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer,
      Int32,
    )>>('jsFreeValueRT')
    .asFunction();

void jsFreeValueRT(
  Pointer rt,
  Pointer val, {
  bool free = true,
}) {
  _jsFreeValueRT(rt, val, free ? 1 : 0);
}

/// JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
final Pointer Function(
  Pointer ctx,
  Pointer val,
) jsDupValue = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>('jsDupValue')
    .asFunction();

/// JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
final Pointer Function(
  Pointer rt,
  Pointer val,
) jsDupValueRT = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>('jsDupValueRT')
    .asFunction();

/// int32_t jsToBool(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsToBool = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>('jsToBool')
    .asFunction();

/// int64_t jsToFloat64(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsToInt64 = _qjsLib
    .lookup<
        NativeFunction<
            Int64 Function(
      Pointer,
      Pointer,
    )>>('jsToInt64')
    .asFunction();

/// double jsToFloat64(JSContext *ctx, JSValueConst *val)
final double Function(
  Pointer ctx,
  Pointer val,
) jsToFloat64 = _qjsLib
    .lookup<
        NativeFunction<
            Double Function(
      Pointer,
      Pointer,
    )>>('jsToFloat64')
    .asFunction();

/// const char *jsToCString(JSContext *ctx, JSValue *val)
final Pointer<Utf8> Function(
  Pointer ctx,
  Pointer val,
) _jsToCString = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<Utf8> Function(
      Pointer,
      Pointer,
    )>>('jsToCString')
    .asFunction();

/// void jsFreeCString(JSContext *ctx, const char *ptr)
final void Function(
  Pointer ctx,
  Pointer<Utf8> val,
) jsFreeCString = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer<Utf8>,
    )>>('jsFreeCString')
    .asFunction();

String jsToCString(
  Pointer ctx,
  Pointer val,
) {
  final ptr = _jsToCString(ctx, val);
  if (ptr.address == 0) throw Exception('JSValue cannot convert to string');
  final str = ptr.toDartString();
  jsFreeCString(ctx, ptr);
  return str;
}

/// DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
final int Function(
  Pointer ctx,
  Pointer<Utf8> name,
) _jsNewClass = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
      Pointer,
      Pointer<Utf8>,
    )>>('jsNewClass')
    .asFunction();

int jsNewClass(
  Pointer ctx,
  String name,
) {
  final utf8name = name.toNativeUtf8();
  final val = _jsNewClass(
    ctx,
    utf8name,
  );
  malloc.free(utf8name);
  return val;
}

/// DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
final Pointer Function(
  Pointer ctx,
  int classId,
  int opaque,
) jsNewObjectClass = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Uint32,
      IntPtr,
    )>>('jsNewObjectClass')
    .asFunction();

/// DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
final int Function(
  Pointer obj,
  int classid,
) jsGetObjectOpaque = _qjsLib
    .lookup<
        NativeFunction<
            IntPtr Function(
      Pointer,
      Uint32,
    )>>('jsGetObjectOpaque')
    .asFunction();

/// uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
final Pointer<Uint8> Function(
  Pointer ctx,
  Pointer<IntPtr> psize,
  Pointer val,
) jsGetArrayBuffer = _qjsLib
    .lookup<
        NativeFunction<
            Pointer<Uint8> Function(
      Pointer,
      Pointer<IntPtr>,
      Pointer,
    )>>('jsGetArrayBuffer')
    .asFunction();

/// int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsFunction = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>('jsIsFunction')
    .asFunction();

/// int32_t jsIsPromise(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsPromise = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>('jsIsPromise')
    .asFunction();

/// int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsArray = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>('jsIsArray')
    .asFunction();

/// DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValueConst *val);
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsError = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>('jsIsError')
    .asFunction();

/// DLLEXPORT JSValue *jsNewError(JSContext *ctx);
final Pointer Function(
  Pointer ctx,
) jsNewError = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsNewError')
    .asFunction();

/// JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop)
final Pointer Function(
  Pointer ctx,
  Pointer thisObj,
  int prop,
) jsGetProperty = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
      Uint32,
    )>>('jsGetProperty')
    .asFunction();

/// int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop, JSValue *val, int flags)
final int Function(
  Pointer ctx,
  Pointer thisObj,
  int prop,
  Pointer val,
  int flag,
) jsDefinePropertyValue = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
      Uint32,
      Pointer,
      Int32,
    )>>('jsDefinePropertyValue')
    .asFunction();

/// void jsFreeAtom(JSContext *ctx, JSAtom v)
final Pointer Function(
  Pointer ctx,
  int v,
) jsFreeAtom = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Uint32,
    )>>('jsFreeAtom')
    .asFunction();

/// JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsValueToAtom = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
      Pointer,
      Pointer,
    )>>('jsValueToAtom')
    .asFunction();

/// JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsAtomToValue = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Uint32,
    )>>('jsAtomToValue')
    .asFunction();

/// int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
///                           uint32_t *plen, JSValueConst *obj, int flags)
final int Function(
  Pointer ctx,
  Pointer<Pointer> ptab,
  Pointer<Uint32> plen,
  Pointer obj,
  int flags,
) jsGetOwnPropertyNames = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer<Pointer>,
      Pointer<Uint32>,
      Pointer,
      Int32,
    )>>('jsGetOwnPropertyNames')
    .asFunction();

/// JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
final int Function(
  Pointer ptab,
  int i,
) jsPropertyEnumGetAtom = _qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
      Pointer,
      Int32,
    )>>('jsPropertyEnumGetAtom')
    .asFunction();

/// uint32_t sizeOfJSValue()
final int Function() _sizeOfJSValue = _qjsLib
    .lookup<NativeFunction<Uint32 Function()>>('sizeOfJSValue')
    .asFunction();

final sizeOfJSValue = _sizeOfJSValue();

/// void setJSValueList(JSValue *list, int i, JSValue *val)
final void Function(
  Pointer list,
  int i,
  Pointer val,
) setJSValueList = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Uint32,
      Pointer,
    )>>('setJSValueList')
    .asFunction();

/// JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
///                 int argc, JSValueConst *argv)
final Pointer Function(
  Pointer ctx,
  Pointer funcObj,
  Pointer thisObj,
  int argc,
  Pointer argv,
) _jsCall = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
      Pointer,
      Int32,
      Pointer,
    )>>('jsCall')
    .asFunction();

Pointer jsCall(
  Pointer ctx,
  Pointer funcObj,
  Pointer thisObj,
  List<Pointer> argv,
) {
  Pointer jsArgs = calloc<Uint8>(
    argv.length > 0 ? sizeOfJSValue * argv.length : 1,
  );
  for (int i = 0; i < argv.length; ++i) {
    Pointer jsArg = argv[i];
    setJSValueList(jsArgs, i, jsArg);
  }
  Pointer func1 = jsDupValue(ctx, funcObj);
  Pointer _thisObj = thisObj ?? jsUNDEFINED();
  Pointer jsRet = _jsCall(ctx, funcObj, _thisObj, argv.length, jsArgs);
  if (thisObj == null) {
    jsFreeValue(ctx, _thisObj);
  }
  jsFreeValue(ctx, func1);
  malloc.free(jsArgs);
  runtimeOpaques[jsGetRuntime(ctx)]._port.sendPort.send(#call);
  return jsRet;
}

/// int jsIsException(JSValueConst *val)
final int Function(
  Pointer val,
) jsIsException = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>('jsIsException')
    .asFunction();

/// JSValue *jsGetException(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsGetException = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>('jsGetException')
    .asFunction();

/// int jsExecutePendingJob(JSRuntime *rt)
final int Function(
  Pointer ctx,
) jsExecutePendingJob = _qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>('jsExecutePendingJob')
    .asFunction();

/// JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
final Pointer Function(
  Pointer ctx,
  Pointer resolvingFuncs,
) jsNewPromiseCapability = _qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>('jsNewPromiseCapability')
    .asFunction();

/// void jsFree(JSContext *ctx, void *ptab)
final void Function(
  Pointer ctx,
  Pointer ptab,
) jsFree = _qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer,
    )>>('jsFree')
    .asFunction();
