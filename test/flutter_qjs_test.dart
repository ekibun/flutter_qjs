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

dynamic myFunction(String args, {String thisVal}) {
  return [thisVal, args];
}

Future testEvaluate(qjs) async {
  final testWrap = await qjs.evaluate("(a) => a", name: "<testWrap>");
  final primities = [0, 1, 0.1, true, false, "str"];
  final wrapPrimities = await testWrap(primities);
  for (var i = 0; i < primities.length; i++) {
    expect(wrapPrimities[i], primities[i], reason: "wrap primities");
  }
  final a = {};
  a["a"] = a;
  final wrapA = await testWrap(a);
  expect(wrapA['a'], wrapA, reason: "recursive object");
  final testThis = await qjs.evaluate(
    "(func) => func.call('this', 'arg')",
    name: "<testThis>",
  );
  final funcRet = await testThis(myFunction);
  expect(funcRet[0], 'this', reason: "js function this");
  expect(funcRet[1], 'arg', reason: "js function argument");
  final promises = await testWrap(await qjs.evaluate(
    "[Promise.reject('test Promise.reject'), Promise.resolve('test Promise.resolve')]",
    name: "<promises>",
  ));
  for (final promise in promises)
    expect(promise, isInstanceOf<Future>(), reason: "promise object");
  try {
    await promises[0];
    throw 'Future not reject';
  } catch (e) {
    expect(e, startsWith('test Promise.reject\n'),
        reason: "promise object reject");
  }
  expect(await promises[1], 'test Promise.resolve',
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
  test('data conversion', () async {
    final qjs = FlutterQjs(
      moduleHandler: (name) {
        return "export default '${new DateTime.now()}'";
      },
      hostPromiseRejectionHandler: (_) {},
    );
    qjs.dispatch();
    await testEvaluate(qjs);
    qjs.close();
  });
  test('isolate conversion', () async {
    final qjs = IsolateQjs(
      moduleHandler: (name) async {
        return "export default '${new DateTime.now()}'";
      },
      hostPromiseRejectionHandler: (_) {},
    );
    await testEvaluate(qjs);
    qjs.close();
  });
  test('isolate bind function', () async {
    final qjs = IsolateQjs();
    var localVar;
    final testFunc = await qjs.evaluate("(func)=>func('ret')", name: "<eval>");
    final testFuncRet = await testFunc(await qjs.bind((args) {
      localVar = 'test';
      return args;
    }));
    expect(localVar, 'test', reason: "bind function");
    expect(testFuncRet, 'ret', reason: "bind function args return");
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
