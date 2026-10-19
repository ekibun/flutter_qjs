import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:highlight/highlight.dart';

const Map<String, TextStyle> _theme = a11yLightTheme;

/// Splits [code] into styled spans. Top level so that it can run in an isolate
/// through `compute`.
List<TextSpan> _convert(String code) {
  final nodes = highlight.parse(code, language: 'javascript').nodes;
  final spans = <TextSpan>[];
  var currentSpans = spans;
  final stack = <List<TextSpan>>[];

  void traverse(Node node) {
    final value = node.value;
    final className = node.className;
    final children = node.children;
    if (value != null) {
      currentSpans.add(
        TextSpan(
          text: value,
          style: className == null ? null : _theme[className],
        ),
      );
    } else if (children != null) {
      final tmp = <TextSpan>[];
      currentSpans.add(
        TextSpan(
          children: tmp,
          style: className == null ? null : _theme[className],
        ),
      );
      stack.add(currentSpans);
      currentSpans = tmp;

      for (var i = 0; i < children.length; i++) {
        traverse(children[i]);
        if (i == children.length - 1) {
          currentSpans = stack.isEmpty ? spans : stack.removeLast();
        }
      }
    }
  }

  for (final node in nodes ?? const <Node>[]) {
    traverse(node);
  }

  return spans;
}

/// A [TextEditingController] that renders javascript with syntax highlighting
/// while keeping the caret position intact.
class CodeInputController extends TextEditingController {
  CodeInputController({super.text});

  TextSpan _oldSpan = const TextSpan();
  Future<void>? _spanCall;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final oldText = _oldSpan.toPlainText();
    final newText = value.text;
    if (oldText == newText) return _oldSpan;

    (_spanCall?.timeout(Duration.zero) ?? Future<void>.value())
        .then((_) {
          _spanCall = compute(_convert, newText).then((spans) {
            final newSpan = TextSpan(style: style, children: spans);
            if (newSpan.toPlainText() == value.text) _oldSpan = newSpan;
            notifyListeners();
          });
        })
        .catchError((Object _) {});

    final oldChildren = _oldSpan.children ?? const <InlineSpan>[];
    final beforeSpans = <TextSpan>[];
    var splitAt = value.selection.start;
    if (splitAt < 0) splitAt = newText.length ~/ 2;
    var start = 0;
    InlineSpan? leftSpan;
    for (final element in oldChildren) {
      final elementText = element.toPlainText();
      if (start + elementText.length > splitAt ||
          !newText.startsWith(elementText, start)) {
        leftSpan = element;
        break;
      }
      beforeSpans.add(element as TextSpan);
      start += elementText.length;
    }

    final endSpans = <TextSpan>[];
    var end = 0;
    InlineSpan? rightSpan;
    for (final element in oldChildren.reversed) {
      final elementText = element.toPlainText();
      if (splitAt + end + elementText.length >= newText.length ||
          !newText
              .substring(start, max(start, newText.length - end))
              .endsWith(elementText)) {
        rightSpan = element;
        break;
      }
      endSpans.add(element as TextSpan);
      end += elementText.length;
    }

    return TextSpan(
      style: style,
      children: [
        ...beforeSpans,
        TextSpan(
          style: leftSpan != null && leftSpan == rightSpan
              ? leftSpan.style
              : style,
          text: newText.substring(start, max(start, newText.length - end)),
        ),
        ...endSpans.reversed,
      ],
    );
  }
}
