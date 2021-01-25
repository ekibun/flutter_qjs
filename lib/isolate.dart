/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'flutter_qjs.dart';
import 'wrapper.dart';

void _runJsIsolate(Map spawnMessage) async {
  SendPort sendPort = spawnMessage['port'];
  ReceivePort port = ReceivePort();
  sendPort.send(port.sendPort);
  var qjs = FlutterQjs(
    stackSize: spawnMessage['stackSize'],
    hostPromiseRejectionHandler: (reason) {
      sendPort.send({
        'type': 'hostPromiseRejection',
        'reason': reason,
      });
    },
    moduleHandler: (name) {
      var ptr = allocate<Pointer<Utf8>>();
      ptr.value = Pointer.fromAddress(0);
      sendPort.send({
        'type': 'module',
        'name': name,
        'ptr': ptr.address,
      });
      while (ptr.value.address == 0) sleep(Duration.zero);
      if (ptr.value.address == -1) throw Exception('Module Not found');
      var ret = Utf8.fromUtf8(ptr.value);
      sendPort.send({
        'type': 'release',
        'ptr': ptr.value.address,
      });
      free(ptr);
      return ret;
    },
  );
  port.listen((msg) async {
    var data;
    SendPort msgPort = msg['port'];
    try {
      switch (msg['type']) {
        case 'evaluate':
          data = await qjs.evaluate(
            msg['command'],
            name: msg['name'],
            evalFlags: msg['flag'],
          );
          break;
        case 'call':
          data = await JSFunction.fromAddress(
            Pointer.fromAddress(msg['ctx']),
            Pointer.fromAddress(msg['val']),
          ).invoke(
            decodeData(msg['args'], null),
            decodeData(msg['this'], null),
          );
          break;
        case 'close':
          qjs.port.close();
          qjs.close();
          port.close();
          break;
      }
      if (msgPort != null)
        msgPort.send({
          'data': encodeData(data),
        });
    } catch (e, stack) {
      if (msgPort != null)
        msgPort.send({
          'error': e.toString() + '\n' + stack.toString(),
        });
    }
  });
  await qjs.dispatch();
}

typedef JsAsyncModuleHandler = Future<String> Function(String name);
typedef JsIsolateSpawn = void Function(SendPort sendPort);

class IsolateQjs {
  Future<SendPort> _sendPort;

  /// Max stack size for quickjs.
  final int stackSize;

  /// Asynchronously handler to manage js module.
  JsAsyncModuleHandler moduleHandler;

  /// Handler function to manage js module.
  JsHostPromiseRejectionHandler hostPromiseRejectionHandler;

  /// Quickjs engine runing on isolate thread.
  ///
  /// Pass handlers to implement js-dart interaction and resolving modules. The `methodHandler` is
  /// used in isolate, so **the handler function must be a top-level function or a static method**.
  IsolateQjs({
    this.moduleHandler,
    this.stackSize,
    this.hostPromiseRejectionHandler,
  });

  _ensureEngine() {
    if (_sendPort != null) return;
    ReceivePort port = ReceivePort();
    Isolate.spawn(
      _runJsIsolate,
      {
        'port': port.sendPort,
        'stackSize': stackSize,
      },
      errorsAreFatal: true,
    );
    var completer = Completer<SendPort>();
    port.listen((msg) async {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
        return;
      }
      switch (msg['type']) {
        case 'hostPromiseRejection':
          try {
            final errStr = msg['reason'];
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler(errStr);
            } else {
              print('unhandled promise rejection: $errStr');
            }
          } catch (e, stack) {
            print('host Promise Rejection Handler error: ' +
                e.toString() +
                '\n' +
                stack.toString());
          }
          break;
        case 'module':
          var ptr = Pointer<Pointer>.fromAddress(msg['ptr']);
          try {
            ptr.value = Utf8.toUtf8(await moduleHandler(msg['name']));
          } catch (e) {
            ptr.value = Pointer.fromAddress(-1);
          }
          break;
        case 'release':
          free(Pointer.fromAddress(msg['ptr']));
          break;
      }
    }, onDone: () {
      close();
      if (!completer.isCompleted) completer.completeError('isolate close');
    });
    _sendPort = completer.future;
  }

  /// Create isolate function
  Future<IsolateFunction> bind(Function func) async {
    _ensureEngine();
    return IsolateFunction.bind(func, await _sendPort);
  }

  /// Free Runtime and close isolate thread that can be recreate when evaluate again.
  close() {
    if (_sendPort == null) return;
    _sendPort.then((sendPort) {
      sendPort.send({
        'type': 'close',
      });
    });
    _sendPort = null;
  }

  /// Evaluate js script.
  Future<dynamic> evaluate(String command, {String name, int evalFlags}) async {
    _ensureEngine();
    var evaluatePort = ReceivePort();
    var sendPort = await _sendPort;
    sendPort.send({
      'type': 'evaluate',
      'command': command,
      'name': name,
      'flag': evalFlags,
      'port': evaluatePort.sendPort,
    });
    Map result = await evaluatePort.first;
    evaluatePort.close();
    if (result.containsKey('data')) {
      return decodeData(result['data'], sendPort);
    } else
      throw result['error'];
  }
}
