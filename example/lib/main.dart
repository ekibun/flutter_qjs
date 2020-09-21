/*
 * @Description: example
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:51
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-21 23:54:55
 */
import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'highlight.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_qjs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(brightness: Brightness.dark, elevation: 0),
        backgroundColor: Colors.grey[300],
        primaryColorBrightness: Brightness.dark,
      ),
      routes: {
        'home': (BuildContext context) => TestPage(),
      },
      initialRoute: 'home',
    );
  }
}

class TestPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String resp;
  FlutterQjs engine;

  CodeInputController _controller = CodeInputController();

  _createEngine() async {
    if (engine != null) return;
    engine = FlutterQjs();
    engine.setMethodHandler((String method, List arg) {
      switch (method) {
        case "http":
          return Dio().get(arg[0]).then((response) => response.data);
        case "test":
          return arg[0]([
            true,
            1,
            0.5,
            "str",
            {"key": "val", 0: 1},
            Uint8List(2),
            Int32List(2),
            Int64List(2),
            Float64List(2),
            Float32List(2)
          ]);
        default:
          throw Exception("No such method");
      }
    });
    engine.setModuleHandler((String module) {
      if (module == "hello") return "export default '${new DateTime.now()}'";
      return "Module Not found";
    });
    engine.dispatch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("JS engine test"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FlatButton(
                      child: Text("create engine"), onPressed: _createEngine),
                  FlatButton(
                      child: Text("evaluate"),
                      onPressed: () async {
                        if (engine == null) {
                          print("please create engine first");
                          return;
                        }
                        try {
                          resp = (await engine.evaluate(
                                  _controller.text ?? '', "<eval>"))
                              .toString();
                        } catch (e) {
                          resp = e.toString();
                        }
                        setState(() {});
                      }),
                  FlatButton(
                      child: Text("close engine"),
                      onPressed: () async {
                        if (engine == null) return;
                        await engine.close();
                        engine = null;
                      }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.withOpacity(0.1),
              constraints: BoxConstraints(minHeight: 200),
              child: TextField(
                  autofocus: true,
                  controller: _controller,
                  decoration: null,
                  expands: true,
                  maxLines: null),
            ),
            SizedBox(height: 16),
            Text("result:"),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withOpacity(0.05),
              constraints: BoxConstraints(minHeight: 100),
              child: Text(resp ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
