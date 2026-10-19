<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 00:44:41
-->
# flutter_qjs

![Pub](https://img.shields.io/pub/v/flutter_qjs.svg)
![Test](https://github.com/ekibun/flutter_qjs/workflows/Test/badge.svg)

[English](README.md) | [中文](README-CN.md)

This plugin is a simple js engine for flutter using the `quickjs` project with `dart:ffi`. Plugin currently supports all the platforms except web!

## Getting Started

### Basic usage

Firstly, create a `FlutterQjs` object:

```dart
final engine = FlutterQjs(
  stackSize: 1024 * 1024, // change stack size here.
);
```

Use `evaluate` method to run js script, it runs synchronously, you can use await to resolve `Promise`:

```dart
try {
  print(engine.evaluate(code ?? ''));
} catch (e) {
  print(e.toString());
}
```

Method `close` can destroy quickjs runtime that can be recreated again if you call `evaluate`. **Reference leak exception will be thrown since v0.3.3**

```dart
try {
  engine.close();      // close engine
} on JSError catch(e) { 
  print(e);            // catch reference leak exception
}
engine = null;
```

Data conversion between dart and js are implemented as follow:

| dart                         | js         |
| ---------------------------- | ---------- |
| Bool                         | boolean    |
| Int                          | number     |
| Double                       | number     |
| String                       | string     |
| Uint8List                    | ArrayBuffer|
| List                         | Array      |
| Map                          | Object     |
| Function(arg1, arg2, ..., {thisVal})<br>JSInvokable.invoke(\[arg1, arg2, ...\], thisVal) | function.call(thisVal, arg1, arg2, ...) |
| Future                       | Promise    |
| JSError                      | Error      |
| Object                       | DartObject |

## Use Modules

ES6 module with `import` function is supported and can be managed in dart with `moduleHandler`:

```dart
final engine = FlutterQjs(
  moduleHandler: (String module) {
    if(module == "hello")
      return "export default (name) => `hello \${name}!`;";
    throw Exception("Module Not found");
  },
);
```

then in JavaScript, `import` function is used to get modules:

```javascript
import("hello").then(({default: greet}) => greet("world"));
```

**notice:** Module handler should be called only once for each module name. To reset the module cache, call `FlutterQjs.close` then `evaluate` again.

To use async function in module handler, try [run on isolate thread](#Run-on-Isolate-Thread)
## Run on Isolate Thread

Create a `IsolateQjs` object, pass handlers to resolving modules. Async function such as `rootBundle.loadString` can be used now to get modules:

```dart
final engine = IsolateQjs(
  moduleHandler: (String module) async {
    return await rootBundle.loadString(
        "js/" + module.replaceFirst(new RegExp(r".js$"), "") + ".js");
  },
);
// not need engine.dispatch(); // no manual event loop
```

Same as run on main thread, use `evaluate` to run js script. In isolate, everything returns asynchronously, use `await` to get the result:

```dart
try {
  print(await engine.evaluate(code ?? ''));
} catch (e) {
  print(e.toString());
}
```

Method `close` can destroy isolate thread that will be recreated again if you call `evaluate`.

## Use Dart Function (Breaking change in v0.3.0)

Js script returning function will be converted to `JSInvokable`. **It does not extend `Function`, use `invoke` method to invoke it**:

```dart
(func as JSInvokable).invoke([arg1, arg2], thisVal);
```

**notice:** evaluation returning `JSInvokable` may cause reference leak.
You should manually call `free` to release JS reference.

```dart
(obj as JSRef).free();
// or JSRef.freeRecursive(obj);
```

Arguments passed into `JSInvokable` will be freed automatically. Use `dup` to keep the reference.

```dart
(obj as JSRef).dup();
// or JSRef.dupRecursive(obj);
```

Since v0.3.0, you can pass a function to `JSInvokable` arguments, and `channel` function is no longer included by default. You can use js function to set dart object globally.
For example, use `Dio` to implement http in qjs:

```dart
final setToGlobalObject = await engine.evaluate("(key, val) => { this[key] = val; }");
await setToGlobalObject.invoke(["http", (String url) {
  return Dio().get(url).then((response) => response.data);
}]);
setToGlobalObject.free();
```

In isolate, top level function passed in `JSInvokable` will be invoked in isolate thread. Use `IsolateFunction` to pass a instant function:

```dart
await setToGlobalObject.invoke([
  "http",
  IsolateFunction((String url) {
    return Dio().get(url).then((response) => response.data);
  }),
]);
```