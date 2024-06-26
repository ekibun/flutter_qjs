/*
 * @Description: example
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:51
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:28:06
 */
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'highlight.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_qjs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  String resp = '';
  late IsolateQjs engine;

  CodeInputController _controller = CodeInputController(
    text: 'import("hello").then(({default: greet}) => greet("world"));',
  );

  @override
  void initState() {
    super.initState();

    engine = _createEngine();
  }

  IsolateQjs _createEngine() {
    return IsolateQjs(
      moduleHandler: (String module) async {
        return await rootBundle.loadString(
          "js/" + module.replaceFirst(new RegExp(r".js$"), "") + ".js",
        );
      },
    );
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
                  TextButton(
                      child: Text("evaluate"),
                      onPressed: () async {
                        try {
                          resp = (await engine.evaluate(
                            _controller.text,
                            name: "<eval>",
                          ))
                              .toString();
                          setState(() {});
                        } catch (e) {
                          resp = e.toString();
                          setState(() {});
                        }
                      }),
                  TextButton(
                    child: Text("reset engine"),
                    onPressed: () async {
                      final engineToClose = engine;
                      engine = _createEngine();
                      await engineToClose.close();
                    },
                  ),
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
              child: Text(resp),
            ),
          ],
        ),
      ),
    );
  }
}
