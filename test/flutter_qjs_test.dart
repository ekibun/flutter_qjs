/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-07 00:11:27
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/ffi.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_qjs/isolate.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic myMethodHandler(List args, {String thisVal}) {
  return [thisVal, ...args];
}

Future testEvaluate(qjs) async {
  final value = await qjs.evaluate("""
      const a = {};
      a.a = a;
      import('test').then((module) => channel.call('this', [
          (...args)=>`hello \${args}!`, a,
          Promise.reject('test Promise.reject'), Promise.resolve('test Promise.resolve'),
          0.1, true, false, 1, "world", module
        ]));
      """, name: "<eval>");
  expect(value[0], 'this', reason: "js function this");
  expect(await value[1]('world'), 'hello world!', reason: "js function call");
  expect(value[2]['a'], value[2], reason: "recursive object");
  expect(value[3], isInstanceOf<Future>(), reason: "promise object");
  try {
    await value[3];
    throw 'Future not reject';
  } catch (e) {
    expect(e, startsWith('test Promise.reject\n'),
        reason: "promise object reject");
  }
  expect(await value[4], 'test Promise.resolve',
      reason: "promise object resolve");
}

void main() async {
  test('make', () async {
    final utf8Encoding = Encoding.getByName('utf-8');
    var cmakePath = "cmake";
    if (Platform.isWindows) {
      var vsDir = Directory("C:/Program Files (x86)/Microsoft Visual Studio/");
      vsDir = (vsDir.listSync().firstWhere((e) => e is Directory) as Directory)
          .listSync()
          .last as Directory;
      cmakePath = vsDir.path +
          "/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe";
    }
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
  });
  test('module', () async {
    final qjs = FlutterQjs(
      moduleHandler: (name) {
        return "export default 'test module'";
      },
    );
    qjs.dispatch();
    qjs.evaluate('''
      import handlerData from 'test';
      export default {
        data: handlerData
      };
      ''', name: 'evalModule', evalFlags: JSEvalFlag.MODULE);
    var result = await qjs.evaluate('import("evalModule")');
    expect(result['default']['data'], 'test module', reason: "eval module");
    qjs.close();
  });
  test('jsToDart', () async {
    final qjs = FlutterQjs(
      moduleHandler: (name) {
        return "export default '${new DateTime.now()}'";
      },
      hostPromiseRejectionHandler: (_) {},
    );
    qjs.setToGlobalObject("channel", myMethodHandler);
    qjs.dispatch();
    await testEvaluate(qjs);
    qjs.close();
  });
  test('isolate', () async {
    await runZonedGuarded(() async {
      final qjs = IsolateQjs(
        moduleHandler: (name) async {
          return "export default '${new DateTime.now()}'";
        },
        hostPromiseRejectionHandler: (_) {},
      );
      await qjs.setToGlobalObject("channel", myMethodHandler);
      await testEvaluate(qjs);
      qjs.close();
    }, (e, stack) {
      if (!e.toString().startsWith("test Promise.reject")) throw e;
    });
  });
  test('dart object', () async {
    final qjs = FlutterQjs();
    qjs.setToGlobalObject("channel", () {
      return FlutterQjs();
    });
    qjs.dispatch();
    var value = await qjs.evaluate("channel()", name: "<eval>");
    expect(value, isInstanceOf<FlutterQjs>(), reason: "dart object");
    qjs.close();
  });
  test('stack overflow', () async {
    final qjs = FlutterQjs();
    try {
      qjs.evaluate("a=()=>a();a();", name: "<eval>");
    } catch (e) {
      expect(
          e.toString(), startsWith('Exception: InternalError: stack overflow'),
          reason: "throw stack overflow");
    }
    qjs.close();
  });
  test('host promise rejection', () async {
    final completer = Completer();
    final qjs = FlutterQjs(
      hostPromiseRejectionHandler: (reason) {
        completer.complete(reason);
      },
    );
    qjs.dispatch();
    qjs.evaluate(
        "(() => { Promise.resolve().then(() => { throw 'unhandle' }) })()",
        name: "<eval>");
    Future.delayed(Duration(seconds: 10)).then((value) {
      if (!completer.isCompleted) completer.completeError("not host reject");
    });
    expect(await completer.future, "unhandle",
        reason: "host promise rejection");
    qjs.close();
  });
}
