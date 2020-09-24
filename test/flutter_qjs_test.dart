/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-24 22:55:33
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/ffi.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  test('make.windows', () async {
    final utf8Encoding = Encoding.getByName('utf-8');
    final cmakePath =
        "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe";
    final buildDir = "./build";
    var result = Process.runSync(
      cmakePath,
      ['-S', './', '-B', buildDir],
      workingDirectory: 'test',
      stdoutEncoding: utf8Encoding,
      stderrEncoding: utf8Encoding,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0);

    result = Process.runSync(
      cmakePath,
      ['--build', buildDir, '--verbose'],
      workingDirectory: 'test',
      stdoutEncoding: utf8Encoding,
      stderrEncoding: utf8Encoding,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0);
  }, testOn: 'windows');
  test('make.macos', () async {
    var result = Process.runSync(
      "sh",
      ['./make.sh'],
      workingDirectory: 'macos',
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0);
  }, testOn: 'mac-os');
  test('jsToDart', () async {
    final qjs = FlutterQjs();
    qjs.setMethodHandler((method, args) {
      print([method, args]);
      return args;
    });
    qjs.setModuleHandler((name) {
      print(name);
      return "export default '${new DateTime.now()}'";
    });
    qjs.evaluate("""
      const a = {};
      a.a = a;
      import("test").then((module) => channel('channel', [
          (...a)=>`hello \${a}`,
          0.1, true, false, 1, "world", module
        ]));
      """, "<eval>").then((value) {
      print(value);
    });
    Future.delayed(Duration(seconds: 5)).then((v) {
      qjs.close();
    });
    await qjs.dispatch();
  });
}
