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
  final testWrap = await qjs.evaluate(
    '(a) => a',
    name: '<testWrap>',
  );
  final wrapNull = await testWrap(null);
  expect(wrapNull, null, reason: 'wrap null');
  final primities = [0, 1, 0.1, true, false, 'str'];
  final wrapPrimities = await testWrap(primities);
  for (int i = 0; i < primities.length; i++) {
    expect(wrapPrimities[i], primities[i], reason: 'wrap primities');
  }
  final jsError = JSError('test Error');
  final wrapJsError = await testWrap(jsError);
  expect(jsError.message, (wrapJsError as JSError).message,
      reason: 'wrap JSError');
  final wrapFunction = await testWrap(testWrap);
  final testEqual = await qjs.evaluate(
    '(a, b) => a === b',
    name: '<testEqual>',
  );
  expect(await testEqual(wrapFunction, testWrap), true,
      reason: 'wrap function');
  wrapFunction.release();
  testEqual.release();

  expect(wrapNull, null, reason: 'wrap null');
  final a = {};
  a['a'] = a;
  final wrapA = await testWrap(a);
  expect(wrapA['a'], wrapA, reason: 'recursive object');
  final testThis = await qjs.evaluate(
    '(function (func, arg) { return func.call(this, arg) })',
    name: '<testThis>',
  );
  final funcRet = await testThis(myFunction, 'arg', thisVal: {'name': 'this'});
  testThis.release();
  expect(funcRet[0]['name'], 'this', reason: 'js function this');
  expect(funcRet[1], 'arg', reason: 'js function argument');
  final promises = await testWrap(await qjs.evaluate(
    '[Promise.reject("reject"), Promise.resolve("resolve"), new Promise(() => {})]',
    name: '<promises>',
  ));
  for (final promise in promises)
    expect(promise, isInstanceOf<Future>(), reason: 'promise object');
  try {
    await promises[0];
    throw 'Future not reject';
  } catch (e) {
    expect(e, 'reject', reason: 'promise object reject');
  }
  expect(await promises[1], 'resolve', reason: 'promise object resolve');
  testWrap.release();
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
  test('isolate bind function', () async {
    final qjs = IsolateQjs();
    var localVar;
    final testFunc = await qjs.evaluate('(func)=>func("ret")', name: '<eval>');
    final testFuncRet = await testFunc(await qjs.bind((args) {
      localVar = 'test';
      return args;
    }));
    testFunc.release();
    expect(localVar, 'test', reason: 'bind function');
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
