<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 00:44:41
-->
# flutter_qjs

A quickjs engine for flutter.

## Feature

This plugin is a simple js engine for flutter using the `quickjs` project with `dart:ffi`. Plugin currently supports all the platforms except web!

Event loop of `FlutterQjs` should be implemented by calling `FlutterQjs.dispatch()`. 

ES6 module with `import` function is supported and can be managed in dart with `setModuleHandler`.

A global function `channel` is presented to invoke dart function. Data conversion between dart and js are implemented as follow:

| dart                                                | js                 |
| --------------------------------------------------- | ------------------ |
| Bool                                                | boolean            |
| Int                                                 | number             |
| Double                                              | number             |
| String                                              | string             |
| Uint8List                                           | ArrayBuffer        |
| List                                                | Array              |
| Map                                                 | Object             |
| JSFunction(...args) <br> IsolateJSFunction(...args) | function(....args) |
| Future                                              | Promise            |

**notice:** `function` can only be sent from js to dart. `IsolateJSFunction` always returns asynchronously.

## Getting Started

### Run on main thread

1. Create a `FlutterQjs` object, pass handlers to implement js-dart interaction and resolving modules. For example, you can use `Dio` to implement http in js:

```dart
final engine = FlutterQjs(
  methodHandler: (String method, List arg) {
    switch (method) {
      case "http":
        return Dio().get(arg[0]).then((response) => response.data);
      default:
        throw Exception("No such method");
    }
  },
  moduleHandler: (String module) {
    if(module == "hello")
      return "export default (name) => `hello \${name}!`;";
    throw Exception("Module Not found");
  },
);
```

in javascript, `channel` function is equiped to invoke `methodHandler`, make sure the second parameter is a list:

```javascript
channel("http", ["http://example.com/"]);
```

`import` function is used to get modules:

```javascript
import("hello").then(({default: greet}) => greet("world"));
```

**notice:** To use async function in module handler, try [Run on isolate thread](#Run-on-isolate-thread)

2. Then call `dispatch` to dispatch event loop.

```dart
engine.dispatch();
```

1. Use `evaluate` to run js script, now you can use it synchronously, or use await to resolve `Promise`:

```dart
try {
  print(engine.evaluate(code ?? ''));
} catch (e) {
  print(e.toString());
}
```

1. Method `close` can destroy quickjs runtime that can be recreated again if you call `evaluate`.

### Run on isolate thread

1. Create a `IsolateQjs` object, pass handlers to implement js-dart interaction and resolving modules. The `methodHandler` is used in isolate, so **the handler function must be a top-level function or a static method**. Async function such as `rootBundle.loadString` can be used now to get module:

```dart
dynamic methodHandler(String method, List arg) {
  switch (method) {
    case "http":
      return Dio().get(arg[0]).then((response) => response.data);
    default:
      throw Exception("No such method");
  }
}
final engine = IsolateQjs(
  methodHandler: methodHandler,
  moduleHandler: (String module) async {
    return await rootBundle.loadString(
        "js/" + module.replaceFirst(new RegExp(r".js$"), "") + ".js");
  },
);
// not need engine.dispatch();
```

2. Same as run on main thread, use `evaluate` to run js script. In this way, `Promise` return by `evaluate` will be automatically tracked and return the resolved data:

```dart
try {
  print(await engine.evaluate(code ?? '', "<eval>"));
} catch (e) {
  print(e.toString());
}
```

3. Method `close` can destroy quickjs runtime that can be recreated again if you call `evaluate`.

[This example](example/lib/main.dart) contains a complete demonstration on how to use this plugin.

## For Mac & IOS developer

I am new to Xcode and iOS developing, and I cannot find a better way to support both simulators and real devices without combining the binary frameworks. To reduce build size, change the `s.vendored_frameworks` in `ios/flutter_qjs.podspec` to the specific framework.

For simulator, use:

```podspec
s.vendored_frameworks = `build/Debug-iphonesimulator/ffiquickjs.framework`
```

For real device, use:

```podspec
s.vendored_frameworks = `build/Debug-iphoneos/ffiquickjs.framework`
```

Two additional notes:

1. quickjs built with `release` config has bug in resolving `Promise`. Please let me know if you know the solution.

2. `ios/make.sh` limit the build architectures to avoid combine conflicts. Change the `make.sh` to support another architectures.