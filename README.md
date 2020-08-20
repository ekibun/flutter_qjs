<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-20 12:02:54
-->
# flutter_qjs

A quickjs engine for flutter.

## Feature

This plugin is a simple js engine for flutter used `quickjs` project. Plugin currently supports Windows, Linux, and Android.

Each `FlutterJs` object creates a new thread that runs a simple js loop. A global async function `dart` is presented to invoke dart function, and `Promise` is supported so that you can use `await` or `then` to get external result from `dart`. 

Data convertion between dart and js are implemented as follow:

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

1. Creat a `FlutterJs` object. Make sure call `close` to terminate thread and release memory when you don't need it.

```dart
FlutterJs engine = FlutterJs();
// do something ...
await engine.destroy();
engine = null;
```

2. Call `setMethodHandler` to implements `dart` interaction. For example, you can use `Dio` to implements http in js:

```dart
engine.setMethodHandler((String method, List arg) async {
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
dart("http", "https://baidu.com");
```

3. Use `evaluate` to run js script, and try-cacth is needed to capture exception.

```
try {
  resp = "${await engine.evaluate(code ?? '', "<eval>")}";
} catch (e) {
  resp = e.toString();
}
```

[Example](example/lib/test.dart) contains a fully use of this plugin. 

**notice:**
To use this plugin in Linux desktop application, you must change `cxx_std_14` to `cxx_std_17` in your project's `CMakeLists.txt`.