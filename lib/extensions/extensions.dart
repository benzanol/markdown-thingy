import 'dart:io';

import 'package:notes/structure/parse_structure.dart';


const String lensDirectory = 'lenses';
const String lensExtension = '.md';


class LensExtension {
  LensExtension({
      required this.name,
      required this.toStateCode,
      required this.toUiCode,
      required this.toStringCode,
  });
  final String name;
  final String toStateCode;
  final String toUiCode;
  final String toStringCode;
}

Future<void> getExtensions(Directory rootDir) async {
  final lensDir = Directory.fromUri(rootDir.uri.resolve(lensDirectory));
  final subDirs = (await lensDir.list().toList()).whereType<Directory>();

  final subDirFutures = subDirs.map((subDir) async {
      // Get a list of markdown files within the subdirectory
      final files = (await subDir.list().toList()).whereType<File>()
      .where((f) => f.path.endsWith(lensExtension))
      .toList();

      final fileBodies = await Future.wait(files.map((f) => f.readAsString()));
      final lenses = fileBodies.map((body) {
          final struct = parseStructure(body.split('\n'));
      });
  });

  await Future.wait(subDirFutures);
}
