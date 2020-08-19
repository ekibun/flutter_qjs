/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-07-18 23:28:55
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-19 13:26:52
 */
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'code/editor.dart';

class TestPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String code, resp;
  FlutterJs engine;

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
                      child: Text("create engine"),
                      onPressed: () async {
                        if (engine != null) return;
                        engine = FlutterJs();
                        engine.setMethodHandler((String method, List arg) async {
                          switch (method) {
                            case "delay":
                              await Future.delayed(Duration(milliseconds: arg[0]));
                              return;
                            case "http":
                              Response response = await Dio()
                                  .get(arg[0], options: Options(responseType: ResponseType.bytes));
                              return response.data;
                            case "hello":
                              return await arg[0](["hello: "]);
                            case "test":
                              return [
                                true, 
                                1, 
                                0.5, 
                                "str", 
                                { "key": "val", 0: 1 }, 
                                Uint8List(2), 
                                Int32List(2), 
                                Int64List(2), 
                                Float64List(2), 
                                Float32List(2)];
                            default:
                              return JsMethodHandlerNotImplement();
                          }
                        });
                      }),
                  FlatButton(
                      child: Text("evaluate"),
                      onPressed: () async {
                        if (engine == null) {
                          print("please create engine first");
                          return;
                        }
                        try {
                          resp = "${await engine.evaluate(code ?? '', "<eval>")}";
                        } catch (e) {
                          resp = e.toString();
                        }
                        setState(() {});
                      }),
                  FlatButton(
                      child: Text("close engine"),
                      onPressed: () async {
                        if (engine != null) return;
                        await engine.destroy();
                        engine = null;
                      }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.withOpacity(0.1),
              constraints: BoxConstraints(minHeight: 200),
              child: CodeEditor(
                onChanged: (v) {
                  code = v;
                },
              ),
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
