/*
 * @Description: unit test
 * @Author: ekibun
 * @Date: 2020-09-06 13:02:46
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-07 00:11:27
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic myFunction(String args, {thisVal}) {
  return [thisVal, args];
}

Future testEvaluate(qjs) async {
  JSInvokable wrapFunction = await qjs.evaluate(
    'async (a) => a',
    name: '<testWrap>',
  );
  dynamic testWrap = await wrapFunction.invoke([wrapFunction]);
  final wrapNull = await testWrap.invoke([null]);
  expect(wrapNull, null, reason: 'wrap null');
  final primities = [0, 1, 0.1, true, false, 'str'];
  final wrapPrimities = await testWrap.invoke([primities]);
  for (int i = 0; i < primities.length; i++) {
    expect(wrapPrimities[i], primities[i], reason: 'wrap primities');
  }
  final jsError = JSError('test Error');
  final wrapJsError = await testWrap.invoke([jsError]);
  expect(jsError.message, (wrapJsError as JSError).message,
      reason: 'wrap JSError');

  expect(wrapNull, null, reason: 'wrap null');
  final a = {};
  a['a'] = a;
  final wrapA = await testWrap.invoke([a]);
  expect(wrapA['a'], wrapA, reason: 'recursive object');
  JSInvokable testThis = await qjs.evaluate(
    '(function (func, arg) { return func.call(this, arg) })',
    name: '<testThis>',
  );
  final funcRet = await testThis.invoke([myFunction, 'arg'], {'name': 'this'});
  testThis.free();
  expect(funcRet[0]['name'], 'this', reason: 'js function this');
  expect(funcRet[1], 'arg', reason: 'js function argument');
  List promises = await testWrap.invoke([
    await qjs.evaluate(
      '[Promise.reject("reject"), Promise.resolve("resolve"), new Promise(() => {})]',
      name: '<promises>',
    )
  ]);
  for (final promise in promises)
    expect(promise, isInstanceOf<Future>(), reason: 'promise object');
  try {
    await promises[0];
    throw 'Future not reject';
  } catch (e) {
    expect(e, 'reject', reason: 'promise object reject');
  }
  expect(await promises[1], 'resolve', reason: 'promise object resolve');
  testWrap.free();
  wrapFunction.free();
}

void main() async {
  test('make', () async {
    final utf8Encoding = Encoding.getByName('utf-8');
    var cmakePath = 'cmake';
    if (Platform.isWindows) {
      var vsDir = Directory('C:/Program Files (x86)/Microsoft Visual Studio/');
      vsDir = (vsDir.listSync().firstWhere((e) => e is Directory) as Directory)
          .listSync()
          .last as Directory;
      cmakePath = vsDir.path +
          '/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe';
    }
    final buildDir = './build';
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
        return 'export default "test module"';
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
    expect(result['default']['data'], 'test module', reason: 'eval module');
    qjs.close();
  });
  test('data conversion', () async {
    final qjs = FlutterQjs(
      hostPromiseRejectionHandler: (_) {},
    );
    qjs.dispatch();
    await testEvaluate(qjs);
    qjs.close();
  });
  test('isolate conversion', () async {
    final qjs = IsolateQjs(
      hostPromiseRejectionHandler: (_) {},
    );
    await testEvaluate(qjs);
    await qjs.close();
  });
  test('isolate bind this', () async {
    final qjs = IsolateQjs();
    JSInvokable localVar;
    JSInvokable setToGlobal = await qjs
        .evaluate('(name, func)=>{ this[name] = func }', name: '<eval>');
    final func = IsolateFunction((args) {
      localVar = args..dup();
      return args.invoke([]);
    });
    await setToGlobal.invoke(["test", func..dup()]);
    func.free();
    setToGlobal.free();
    final testFuncRet = await qjs.evaluate('test(()=>"ret")', name: '<eval>');
    expect(await localVar.invoke([]), 'ret', reason: 'bind function');
    localVar.free();
    expect(testFuncRet, 'ret', reason: 'bind function args return');
    await qjs.close();
  });
  test('reference leak', () async {
    final qjs = FlutterQjs();
    await qjs.evaluate('()=>{}', name: '<eval>');
    try {
      qjs.close();
      throw 'Error not throw';
    } on JSError catch (e) {
      expect(e.message, startsWith('reference leak:'),
          reason: 'throw reference leak');
    }
  });
  test('stack overflow', () async {
    final qjs = FlutterQjs();
    try {
      qjs.evaluate('a=()=>a();a();', name: '<eval>');
      throw 'Error not throw';
    } on JSError catch (e) {
      expect(e.message, 'InternalError: stack overflow',
          reason: 'throw stack overflow');
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
        '(() => { Promise.resolve().then(() => { throw "unhandle" }) })()',
        name: '<eval>');
    Future.delayed(Duration(seconds: 10)).then((value) {
      if (!completer.isCompleted) completer.completeError('not host reject');
    });
    expect(await completer.future, 'unhandle',
        reason: 'host promise rejection');
    qjs.close();
  });
}
