/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-07 00:11:27
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_qjs/isolate.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic myMethodHandler(method, args) {
  return args;
}

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
    final qjs = IsolateQjs(myMethodHandler);
    qjs.setModuleHandler((name) async {
      return "export default '${new DateTime.now()}'";
    });
    var value = await qjs.evaluate("""
      const a = {};
      a.a = a;
      import("test").then((module) => channel('channel', [
          (...args)=>`hello \${args}!`, a,
          0.1, true, false, 1, "world", module
        ]));
      """, name: "<eval>");
    expect(value[1]['a'], value[1], reason: "recursive object");
    expect(await value[0]('world'), 'hello world!', reason: "js function call");
    qjs.close();
  });
  test('stack overflow', () async {
    final qjs = FlutterQjs();
    try {
      await qjs.evaluate("a=()=>a();a();", name: "<eval>");
    } catch (e) {
      expect(
          e.toString(), startsWith('Exception: InternalError: stack overflow'),
          reason: "throw stack overflow");
    }
    qjs.close();
  });
}
