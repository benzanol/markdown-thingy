import 'dart:io';

import 'package:notes/drawer/file_ops.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/lua/result.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


const String extDirectory = 'extensions';
const List<String> extIndexFileNames = ['index.md', 'index.org', 'index.lua'];
const String extsVariable = '*extensions*';

const String extsReturnField = 'value';
const String extsLensesField = 'lenses';
const String extsButtonsField = 'buttons';

bool isExtensionIndexFile(Directory root, File file) {
  if (!file.path.startsWith(root.path)) return false;

  final rootSegs = root.uri.pathSegments.where((seg) => seg.isNotEmpty);
  final relativeSegs = file.uri.pathSegments.sublist(rootSegs.length);
  return (
    relativeSegs.length == 3
    && relativeSegs[0] == extDirectory
    && extIndexFileNames.contains(relativeSegs[2])
  );
}


void runExtensionCode(LuaContext lua, File indexFile, Structure struct) {
  final extDir = indexFile.parent;
  final extLua = lua.inExt(extDir);
  final result = extLua.executeResult(code: struct.getLuaCode());

  // Put the new scope into extensions[name][scope]
  // luaSetTableEntry(lua, extsVariable, [extName, extsScopeField]);

  if (result is LuaFailure) {
    // ignore: avoid_print
    print('Error loading ${fileName(extDir)}: ${result.error}');
  }
}

Future<void> loadExtensions(LuaContext lua, Directory rootDir) async {
  final extensionsDir = Directory.fromUri(rootDir.uri.resolve(extDirectory));
  final subDirs = (await extensionsDir.list().toList()).whereType<Directory>();
  final maybeExtensions = (await Future.wait(
      subDirs.map((dir) async {
          final indexFile = extIndexFileNames
          .map((name) => File.fromUri(dir.uri.resolve(name)))
          .where((file) => file.existsSync())
          .firstOrNull;

          if (indexFile == null) return null;

          final content = await indexFile.readAsString();
          final sp = StructureParser.fromFile(indexFile.path)!;
          return (indexFile, sp.parse(content));
      })
  ));

  for (final maybeExt in maybeExtensions) {
    if (maybeExt == null) return;
    final (indexFile, struct) = maybeExt;
    runExtensionCode(lua, indexFile, struct);
  }
}
