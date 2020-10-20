/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-10-14 19:35:01
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-21 00:43:05
 */
import 'package:flutter_qjs/wasm.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the FlutterQjs plugin.
class FlutterQjsWeb {
  static void registerWith(Registrar registrar) {
    wasmInit();
  }
}
