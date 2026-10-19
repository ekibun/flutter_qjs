# flutter_qjs_example

Demonstrates how to use the flutter_qjs plugin.

The plugin builds quickjs through a Dart build hook, so the package itself has
no platform folders: the native library is produced by `hook/build.dart` and
consumed through a code asset.

```bash
flutter pub get
flutter run          # or: flutter build windows --debug
```
