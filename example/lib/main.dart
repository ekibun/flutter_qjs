import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';

import 'highlight.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_qjs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      home: const TestPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String? _resp;
  IsolateQjs? _engine;

  final CodeInputController _controller = CodeInputController(
    text: 'import("hello").then(({default: greet}) => greet("world"));',
  );

  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    _engine = IsolateQjs(
      moduleHandler: (module) => rootBundle.loadString(
        'js/${module.replaceFirst(RegExp(r'\.js$'), '')}.js',
      ),
    );
  }

  Future<void> _evaluate() async {
    await _ensureEngine();
    try {
      final result = await _engine!.evaluate(_controller.text, name: '<eval>');
      _resp = result.toString();
    } catch (e) {
      _resp = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
    final engine = _engine;
    if (engine == null) return;
    _engine = null;
    await engine.close();
    if (mounted) setState(() => _resp = null);
  }

  @override
  void dispose() {
    _engine?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JS engine test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(onPressed: _evaluate, child: const Text('evaluate')),
                TextButton(
                  onPressed: _reset,
                  child: const Text('reset engine'),
                ),
              ],
            ),
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              color: Colors.grey.withValues(alpha: 0.1),
              child: TextField(
                autofocus: true,
                controller: _controller,
                decoration: const InputDecoration.collapsed(hintText: ''),
                expands: true,
                maxLines: null,
              ),
            ),
            const SizedBox(height: 16),
            const Text('result:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.withValues(alpha: 0.05),
              constraints: const BoxConstraints(minHeight: 100),
              child: Text(_resp ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
