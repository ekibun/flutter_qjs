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

一个为flutter开发的 `quickjs` 引擎。插件基于 `dart:ffi`，支持除Web以外的所有平台！

## 基本使用

首先，创建 `FlutterQjs` 对象。调用 `dispatch` 建立事件循环：

```dart
final engine = FlutterQjs(
  stackSize: 1024 * 1024, // change stack size here.
);
engine.dispatch();
```

使用 `evaluate` 方法运行js脚本，方法同步执行，使用 `await` 来获得 `Promise` 结果：

```dart
try {
  print(engine.evaluate(code ?? ''));
} catch (e) {
  print(e.toString());
}
```

使用 `close` 方法销毁 quickjs 实例，其在再次调用 `evaluate` 时将会重建。当不再需要 `FlutterQjs` 对象时，关闭 `port` 参数来结束事件循环。**在 v0.3.3 后增加了引用检查，可能会抛出异常**。

```dart
try {
  engine.port.close(); // stop dispatch loop
  engine.close();      // close engine
} on JSError catch(e) { 
  print(e);            // catch reference leak exception
}
engine = null;
```

dart 与 js 间数据以如下规则转换：

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

## 使用模块

插件支持 ES6 模块方法 `import`。使用 `moduleHandler` 来处理模块请求：

```dart
final engine = FlutterQjs(
  moduleHandler: (String module) {
    if(module == "hello")
      return "export default (name) => `hello \${name}!`;";
    throw Exception("Module Not found");
  },
);
```

在JavaScript中，`import` 方法用以获取模块：

```javascript
import("hello").then(({default: greet}) => greet("world"));
```

**注：** 模块将只被编译一次. 调用 `FlutterQjs.close` 再 `evaluate` 来重置模块缓存。

若要使用异步方法来处理模块请求，请参见 [在 isolate 中运行](#在-isolate-中运行)。

## 在 isolate 中运行

创建 `IsolateQjs` 对象，设置 `moduleHandler` 来处理模块请求。 现在可以使用异步函数来获得模块字符串，如 `rootBundle.loadString`：

```dart
final engine = IsolateQjs(
  moduleHandler: (String module) async {
    return await rootBundle.loadString(
        "js/" + module.replaceFirst(new RegExp(r".js$"), "") + ".js");
  },
);
// not need engine.dispatch();
```

与在主线程运行一样，使用 `evaluate` 方法运行js脚本。在isolate中，所有结果都将异步返回，使用 `await` 来获取结果：

```dart
try {
  print(await engine.evaluate(code ?? ''));
} catch (e) {
  print(e.toString());
}
```

使用 `close` 方法销毁 isolate 线程，其在再次调用 `evaluate` 时将会重建。

## 调用 Dart 函数

Js脚本返回函数将被转换为 `JSInvokable`。 **它不能像 `Function` 一样调用，请使用 `invoke` 方法来调用**：

```dart
(func as JSInvokable).invoke([arg1, arg2], thisVal);
```

**注：** 返回 `JSInvokable` 可能造成引用泄漏，需要手动调用 `free` 来释放引用：

```dart
(obj as JSRef).free();
// or JSRef.freeRecursive(obj);
```

传递给 `JSInvokable` 的参数将自动释放. 使用 `dup` 来保持引用：

```dart
(obj as JSRef).dup();
// or JSRef.dupRecursive(obj);
```

自 v0.3.0 起，dart 函数可以作为参数传递给 `JSInvokable`，且 `channel` 函数不再默认内置。可以使用如下方法将 dart 函数赋值给全局，例如，使用 `Dio` 来为 qjs 提供 http 支持：

```dart
final setToGlobalObject = await engine.evaluate("(key, val) => { this[key] = val; }");
await setToGlobalObject.invoke(["http", (String url) {
  return Dio().get(url).then((response) => response.data);
}]);
setToGlobalObject.free();
```

在 isolate 模式下，只有顶层和静态函数能作为参数传给 `JSInvokable`，函数将在 isolate 线程中调用。 使用 `IsolateFunction` 来传递局部函数（将在主线程中调用）：

```dart
await setToGlobalObject.invoke([
  "http",
  IsolateFunction((String url) {
    return Dio().get(url).then((response) => response.data);
  }),
]);
```