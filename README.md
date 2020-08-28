<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-27 21:11:55
-->
# flutter_qjs

A quickjs engine for flutter.

## Feature

This plugin is a simple js engine for flutter using the `quickjs` project. Plugin currently supports Windows, Linux, and Android.

Each `FlutterJs` object creates a new thread that runs a simple js loop. 

ES6 module with `import` function is supported and can manage in dart with `setModuleHandler`.

A global async function `dart` is presented to invoke dart function, and `Promise` is supported so that you can use `await` or `then` to get external result from `dart`. Data convertion between dart and js are implemented as follow:

| dart | js |
| --- | --- |
| Bool | boolean |
| Int | number |
| Double | number |
| String | string |
| Uint8List/Int32List/Int64List | ArrayBuffer |
| Float64List | number[] |
| List | Array |
| Map | Object |
| Closure(List) => Future | function(....args) |

**notice:**
1. All the `Uint8List/Int32List/Int64List` sent from dart will be converted to `ArrayBuffer` without marked the size of elements, and the `ArrayBuffer` will be converted to `Uint8List`.

2. `function` can only sent from js to dart and all the arguments will be packed in a dart `List` object.

## Getting Started

1. Create a `FlutterJs` object. Make sure call `destroy` to terminate thread and release memory when you don't need it.

```dart
FlutterJs engine = FlutterJs();
// do something ...
await engine.destroy();
engine = null;
```

2. Call `setMethodHandler` to implements `dart` interaction. For example, you can use `Dio` to implements http in js:

```dart
await engine.setMethodHandler((String method, List arg) async {
  switch (method) {
    case "http":
      Response response = await Dio().get(arg[0]);
      return response.data;
    default:
      return JsMethodHandlerNotImplement();
  }
});
```

and in javascript, call `dart` function to get data:

```javascript
dart("http", "http://example.com/");
```

3. Call `setModuleHandler` to resolve js module. For example, you can use assets files as module:

```dart
await engine.setModuleHandler((String module) async {
  return await rootBundle.loadString(
      "js/" + module.replaceFirst(new RegExp(r".js$"), "") + ".js");
});
```

and in javascript, call `import` function to get module:

```javascript
import("hello").then(({default: greet}) => greet("world"));
```

4. Use `evaluate` to run js script, and try-catch is needed to capture js exception.

```dart
try {
  print(await engine.evaluate(code ?? '', "<eval>"));
} catch (e) {
  print(e.toString());
}
```

[This example](example/lib/main.dart) contains a complete demonstration on how to use this plugin.
