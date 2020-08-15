/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-07-18 23:28:55
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-15 16:39:07
 */
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
        title: Text("JS 引擎功能测试"),
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
                      child: Text("初始化引擎"),
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
                            default:
                          }
                        });
                      }),
                  FlatButton(
                      child: Text("运行"),
                      onPressed: () async {
                        if (engine == null) {
                          print("请先初始化引擎");
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
                      child: Text("释放引擎"),
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
            Text("运行结果："),
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
