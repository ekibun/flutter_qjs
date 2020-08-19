<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-20 00:33:22
-->
# flutter_qjs

A quickjs engine for flutter.

## Feature

This plugin is a simple js engine for flutter used `quickjs` project.

Each `FlutterJs` object create a new thread that running a simple js loop. A global async function `dart` is presented to invoke dart function, and `Promise` is supported in evaluating js script so that you can use `await` or `then` to get external result from `dart`. 

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

1. Creat a `FlutterJs` object. Makes sure call `close` to release memory when not need it.

2. Call `setMethodHandler` to maintain `dart` function.

3. Use `evaluate` to evaluate js script. Makes sure surrounding try-cacth to capture evaluating error.

[this](example/lib/test.dart) contains a fully use of this plugin. 

**notice:**
To use this plugin in Linux desktop application, you must change `cxx_std_14` to `cxx_std_17` in your project's `CMakeLists.txt`.