/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-20 15:55:50
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qjs/ffi.dart';
import 'package:flutter_qjs/wrapper.dart';

void main() async {
  test('make', () async {
    final utf8Encoding = Encoding.getByName('utf-8');
    final cmakePath =
        "C:/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe";
    final buildDir = "./build";
    var result = Process.runSync(
      cmakePath,
      ['-S', './', '-B', buildDir],
      workingDirectory: 'test/lib',
      stdoutEncoding: utf8Encoding,
      stderrEncoding: utf8Encoding,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0);

    result = Process.runSync(
      cmakePath,
      ['--build', buildDir, '--verbose'],
      workingDirectory: 'test/lib',
      stdoutEncoding: utf8Encoding,
      stderrEncoding: utf8Encoding,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    expect(result.exitCode, 0);
  });
  test('jsToDart', () async {
    final rt = jsNewRuntime((ctx, method, argv) {
      var argvs = jsToDart(ctx, argv);
      print([method, argvs]);
      return dartToJs(ctx, [
        argvs,
        {
          [233, 2]: {}
        }
      ]);
    });
    final ctx = jsNewContext(rt);
    final jsval = jsEval(
      ctx,
      """
      const a = {};
      a.a = a;
      channel('channel', [
          0.1, true, false, 1, "world", 
          new ArrayBuffer(2),
          ()=>'hello',
          a
        ]);
      """,
      "<eval>",
      JSEvalType.GLOBAL,
    );
    print(jsToDart(ctx, jsval));
    jsFreeValue(ctx, jsval);
    deleteJSValue(jsval);
    jsFreeContext(ctx);
    jsFreeRuntime(rt);
  });
}
