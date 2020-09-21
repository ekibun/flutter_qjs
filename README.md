<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-22 00:03:48
-->
# flutter_qjs

A quickjs engine for flutter.

## Feature

This plugin is a simple js engine for flutter using the `quickjs` project with `dart:ffi`. Plugin currently supports Windows, Linux, and Android.

Event loop of `FlutterQjs` should be implemented by calling `FlutterQjs.dispatch()`. 

ES6 module with `import` function is supported and can manage in dart with `setModuleHandler`.

A global function `convert` is presented to invoke dart function. Data convertion between dart and js are implemented as follow:

| dart | js |
| --- | --- |
| Bool | boolean |
| Int | number |
| Double | number |
| String | string |
| Uint8List | ArrayBuffer |
| List | Array |
| Map | Object |
| JSFunction | function(....args) |
| Future | Promise |

**notice:** `function` can only sent from js to dart.

## Getting Started

1. Create a `FlutterQjs` object. Call `dispatch` to dispatch event loop.

```dart
final engine = FlutterQjs();
await engine.dispatch();
```

2. Call `setMethodHandler` to implements `dart` interaction. For example, you can use `Dio` to implements http in js:

```dart
await engine.setMethodHandler((String method, List arg) {
  switch (method) {
    case "http":
      return Dio().get(arg[0]).then((response) => response.data);
    default:
      throw Exception("No such method");
  }
});
```

and in javascript, call `convert` function to get data, make sure the second memeber is a list:

```javascript
convert("http", ["http://example.com/"]);
```

3. Call `setModuleHandler` to resolve js module.

**important:** I cannot find a way to convert the sync ffi callback into an async function. So the assets files got by async function `rootBundle.loadString` cannot be used in this version. I will be appreciated that you can provied me a solution to make `ModuleHandler` async.

```dart
await engine.setModuleHandler((String module) {
  if(module == "hello") return "export default (name) => `hello \${name}!`;";
  throw Exception("Module Not found");
});
```

and in javascript, call `import` function to get module:

```javascript
import("hello").then(({default: greet}) => greet("world"));
```

4. Use `evaluate` to run js script:

```dart
try {
  print(await engine.evaluate(code ?? '', "<eval>"));
} catch (e) {
  print(e.toString());
}
```

5. Method `recreate` can free quickjs runtime that can be recreated again when calling `evaluate`, it can be used to reset the module cache. Call `close` to stop `dispatch` when you do not need it.

[This example](example/lib/main.dart) contains a complete demonstration on how to use this plugin.
