/*
 * @Description: isolate
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of '../flutter_qjs.dart';

typedef dynamic _Decode(Map obj, SendPort port);
List<_Decode> _decoders = [
  JSError._decode,
  _IsolateJSFunction._decode,
  _IsolateFunction._decode,
  _JSFunction._decode,
];

abstract class _IsolateEncodable {
  Map _encode();
}

dynamic _encodeData(dynamic data, {Map<dynamic, dynamic> cache}) {
  if (cache == null) cache = Map();
  if (data is _IsolateEncodable) return data._encode();
  if (cache.containsKey(data)) return cache[data];
  if (data is List) {
    final ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(_encodeData(data[i], cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    final ret = {};
    cache[data] = ret;
    for (final entry in data.entries) {
      ret[_encodeData(entry.key, cache: cache)] =
          _encodeData(entry.value, cache: cache);
    }
    return ret;
  }
  if (data is Future) {
    final futurePort = ReceivePort();
    data.then((value) {
      futurePort.first.then((port) {
        futurePort.close();
        (port as SendPort).send(_encodeData(value));
      });
    }, onError: (e) {
      futurePort.first.then((port) {
        futurePort.close();
        (port as SendPort).send({#error: _encodeData(e)});
      });
    });
    return {
      #jsFuturePort: futurePort.sendPort,
    };
  }
  return data;
}

dynamic _decodeData(dynamic data, SendPort port,
    {Map<dynamic, dynamic> cache}) {
  if (cache == null) cache = Map();
  if (cache.containsKey(data)) return cache[data];
  if (data is List) {
    final ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(_decodeData(data[i], port, cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    for (final decoder in _decoders) {
      final decodeObj = decoder(data, port);
      if (decodeObj != null) return decodeObj;
    }
    if (data.containsKey(#jsFuturePort)) {
      SendPort port = data[#jsFuturePort];
      final futurePort = ReceivePort();
      port.send(futurePort.sendPort);
      final futureCompleter = Completer();
      futureCompleter.future.catchError((e) {});
      futurePort.first.then((value) {
        futurePort.close();
        if (value is Map && value.containsKey(#error)) {
          futureCompleter.completeError(_decodeData(value[#error], port));
        } else {
          futureCompleter.complete(_decodeData(value, port));
        }
      });
      return futureCompleter.future;
    }
    final ret = {};
    cache[data] = ret;
    for (final entry in data.entries) {
      ret[_decodeData(entry.key, port, cache: cache)] =
          _decodeData(entry.value, port, cache: cache);
    }
    return ret;
  }
  return data;
}

void _runJsIsolate(Map spawnMessage) async {
  SendPort sendPort = spawnMessage[#port];
  ReceivePort port = ReceivePort();
  sendPort.send(port.sendPort);
  final qjs = FlutterQjs(
    stackSize: spawnMessage[#stackSize],
    hostPromiseRejectionHandler: (reason) {
      sendPort.send({
        #type: #hostPromiseRejection,
        #reason: _encodeData(reason),
      });
    },
    moduleHandler: (name) {
      final ptr = allocate<Pointer<Utf8>>();
      ptr.value = Pointer.fromAddress(0);
      sendPort.send({
        #type: #module,
        #name: name,
        #ptr: ptr.address,
      });
      while (ptr.value.address == 0) sleep(Duration.zero);
      if (ptr.value.address == -1) throw JSError('Module Not found');
      final ret = Utf8.fromUtf8(ptr.value);
      sendPort.send({
        #type: #release,
        #ptr: ptr.value.address,
      });
      free(ptr);
      return ret;
    },
  );
  port.listen((msg) async {
    var data;
    SendPort msgPort = msg[#port];
    try {
      switch (msg[#type]) {
        case #evaluate:
          data = await qjs.evaluate(
            msg[#command],
            name: msg[#name],
            evalFlags: msg[#flag],
          );
          break;
        case #call:
          data = await _JSFunction.fromAddress(
            Pointer.fromAddress(msg[#ctx]),
            Pointer.fromAddress(msg[#val]),
          ).invoke(
            _decodeData(msg[#args], null),
            _decodeData(msg[#thisVal], null),
          );
          break;
        case #closeFunction:
          _JSFunction.fromAddress(
            Pointer.fromAddress(msg[#ctx]),
            Pointer.fromAddress(msg[#val]),
          ).release();
          break;
        case #close:
          data = false;
          qjs.port.close();
          qjs.close();
          port.close();
          data = true;
          break;
      }
      if (msgPort != null) msgPort.send(_encodeData(data));
    } catch (e) {
      if (msgPort != null)
        msgPort.send({
          #error: _encodeData(e),
        });
    }
  });
  await qjs.dispatch();
}

typedef _JsAsyncModuleHandler = Future<String> Function(String name);

class IsolateQjs {
  Future<SendPort> _sendPort;

  /// Max stack size for quickjs.
  final int stackSize;

  /// Asynchronously handler to manage js module.
  _JsAsyncModuleHandler moduleHandler;

  /// Handler function to manage js module.
  _JsHostPromiseRejectionHandler hostPromiseRejectionHandler;

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
        #port: port.sendPort,
        #stackSize: stackSize,
      },
      errorsAreFatal: true,
    );
    final completer = Completer<SendPort>();
    port.listen((msg) async {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
        return;
      }
      switch (msg[#type]) {
        case #hostPromiseRejection:
          try {
            final err = _decodeData(msg[#reason], port.sendPort);
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler(err);
            } else {
              print('unhandled promise rejection: $err');
            }
          } catch (e) {
            print('host Promise Rejection Handler error: $e');
          }
          break;
        case #module:
          final ptr = Pointer<Pointer>.fromAddress(msg[#ptr]);
          try {
            ptr.value = Utf8.toUtf8(await moduleHandler(msg[#name]));
          } catch (e) {
            ptr.value = Pointer.fromAddress(-1);
          }
          break;
        case #release:
          free(Pointer.fromAddress(msg[#ptr]));
          break;
      }
    }, onDone: () {
      close();
      if (!completer.isCompleted)
        completer.completeError(JSError('isolate close'));
    });
    _sendPort = completer.future;
  }

  /// Create isolate function
  Future<_IsolateFunction> bind(Function func) async {
    _ensureEngine();
    return _IsolateFunction._bind(func, await _sendPort);
  }

  /// Free Runtime and close isolate thread that can be recreate when evaluate again.
  close() {
    if (_sendPort == null) return;
    final ret = _sendPort.then((sendPort) async {
      final closePort = ReceivePort();
      sendPort.send({
        #type: #close,
        #port: closePort.sendPort,
      });
      final result = await closePort.first;
      closePort.close();
      if (result is Map && result.containsKey(#error))
        throw _decodeData(result[#error], sendPort);
      return _decodeData(result, sendPort);
    });
    _sendPort = null;
    return ret;
  }

  /// Evaluate js script.
  Future<dynamic> evaluate(String command, {String name, int evalFlags}) async {
    _ensureEngine();
    final evaluatePort = ReceivePort();
    final sendPort = await _sendPort;
    sendPort.send({
      #type: #evaluate,
      #command: command,
      #name: name,
      #flag: evalFlags,
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    evaluatePort.close();
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error], sendPort);
    return _decodeData(result, sendPort);
  }
}
