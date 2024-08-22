import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/save_scope.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


const String extDirectory = 'extensions';
const List<String> extIndexFileNames = ['index.md', 'index.org'];
const String extsVariable = '*extensions*';

const String extsScopeField = 'scope';
const String extsLensesField = 'lenses';
const String extsButtonsField = 'buttons';

// The extension currently being loaded
// This is used for lua functions like deflens and defbutton
Directory? loadingExtension;


void runExtensionCode(LuaState lua, File indexFile, String code) {
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
          final st = StructureType.fromFile(indexFile.path)!;
          return (indexFile, Structure.parse(content, st));
      })
  ));

  for (final maybeExt in maybeExtensions) {
    if (maybeExt == null) return;
    final (indexFile, struct) = maybeExt;
    runExtensionCode(lua, indexFile, struct.getLuaCode());
  }
}
