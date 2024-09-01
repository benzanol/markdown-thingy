import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/save_scope.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


const String extDirectory = 'extensions';
const List<String> extIndexFileNames = ['index.md', 'index.org', 'index.lua'];
const String extsVariable = '*extensions*';

const String extsScopeField = 'scope';
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

// The extension currently being loaded
// This is used for lua functions like deflens and defbutton
Directory? loadingExtension;


void runExtensionCode(LuaState lua, File indexFile, Structure struct) {
  final code = struct.getLuaCode();
  final extDir = indexFile.parent;
  final extName = fileName(extDir);

  loadingExtension = extDir;
  final result = saveLuaScope(lua, (lua) => luaExecuteFile(lua, code, indexFile));
  loadingExtension = null;

  // Put the new scope into extensions[name][scope]
  luaSetTableEntry(lua, extsVariable, [extName, extsScopeField]);

  if (result is LuaFailure) {
    // ignore: avoid_print
    print('Error loading $extName: ${result.error}');
  }
}

Future<void> loadExtensions(LuaState lua, Directory rootDir) async {
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
