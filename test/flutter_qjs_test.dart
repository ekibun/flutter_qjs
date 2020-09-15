/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-13 22:59:06
 */
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  final DynamicLibrary qjsLib = DynamicLibrary.open("test/lib/build/Debug/ffi_library.dll");
  print(qjsLib);
  // JSRuntime *js_NewRuntime(void);
  final Pointer Function() jsNewRuntime =
      qjsLib.lookup<NativeFunction<Pointer Function()>>("jsNewRuntime").asFunction();
  final rt = jsNewRuntime();
  print(rt);
  // JSContext *js_NewContext(JSRuntime *rt);
  final Pointer Function(Pointer rt) jsNewContext =
      qjsLib.lookup<NativeFunction<Pointer Function(Pointer)>>("jsNewContext").asFunction();
  final ctx = jsNewContext(rt);
  print(ctx);
  // JSValue *js_Eval(JSContext *ctx, const char *input, const char *filename, int eval_flags)
  final Pointer Function(Pointer rt, Pointer<Utf8> input, Pointer<Utf8> filename, int evalFlags) jsEval =
      qjsLib.lookup<NativeFunction<Pointer Function(Pointer,Pointer<Utf8>,Pointer<Utf8>, Int32)>>("jsEval").asFunction();
  final jsval = jsEval(ctx, Utf8.toUtf8("`hello \${'world'}!`"), Utf8.toUtf8("<eval>"), 0);
  // const char *js_ToCString(JSContext *ctx, JSValue *val)
  final Pointer<Utf8> Function(Pointer rt, Pointer val) jsToCString =
      qjsLib.lookup<NativeFunction<Pointer<Utf8> Function(Pointer,Pointer)>>("jsToCString").asFunction();
  final str = Utf8.fromUtf8(jsToCString(ctx, jsval));
  print(str);
}
