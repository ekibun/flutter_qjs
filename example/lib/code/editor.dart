/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-01 13:20:06
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-08 17:52:22
 */
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'highlight.dart';

class CodeEditor extends StatefulWidget {
  final void Function(String) onChanged;

  const CodeEditor({Key key, this.onChanged}) : super(key: key);
  @override
  _CodeEditorState createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  CodeInputController _controller = CodeInputController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      controller: _controller,
      textCapitalization: TextCapitalization.none,
      decoration: null,
      maxLines: null,
      onChanged: this.widget.onChanged,
    );
  }
}
