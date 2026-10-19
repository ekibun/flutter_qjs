import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

/// Name of the shared library target in `cxx/CMakeLists.txt`.
const _libraryName = 'flutter_qjs';

/// Asset name of the library inside this package. The resulting asset id is
/// `package:flutter_qjs/src/ffi.dart`, which is what `@DefaultAsset` in
/// `lib/src/ffi.dart` expects.
const _assetName = 'src/ffi.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    hierarchicalLoggingEnabled = true;
    final logger = Logger('flutter_qjs')
      ..level = Level.ALL
      // stdout is reserved for the hook protocol.
      ..onRecord.listen((r) => stderr.writeln('[${r.level}] ${r.message}'));

    // Native sources live in `<package>/cxx`, which holds the CMakeLists.txt.
    final sourceDir = input.packageRoot.resolve('cxx/');
    final installDir = input.outputDirectory.resolve('install/');

    final builder = CMakeBuilder.create(
      name: _libraryName,
      sourceDir: sourceDir,
      defines: {
        'CMAKE_BUILD_TYPE': 'Release',
        'CMAKE_INSTALL_PREFIX': installDir.toFilePath(),
      },
      targets: ['install'],
      logger: logger,
    );

    await builder.run(input: input, output: output, logger: logger);

    final assets = await output.findAndAddCodeAssets(
      input,
      // Key is the library name, value is the asset name part of the asset id.
      names: {_libraryName: _assetName},
      outDir: installDir,
      logger: logger,
    );
    if (assets.isEmpty) {
      throw BuildError(
        message:
            'CMake did not produce "$_libraryName" in $installDir.\n'
            'Expected asset id: package:flutter_qjs/$_assetName',
      );
    }

    // Re-run the hook when the native sources change.
    output.dependencies.add(sourceDir.resolve('ffi.cpp'));
    output.dependencies.add(sourceDir.resolve('ffi.h'));
    output.dependencies.add(sourceDir.resolve('CMakeLists.txt'));
  });
}
