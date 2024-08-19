import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_result.dart';
import 'package:notes/extensions/lua_utils.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/structure.dart';


const String extDirectory = 'extensions';
const String extIndexFileName = 'index.md';
const String extsVariable = '__extensions__';

const String extsScopeField = 'scope';
const String extsLensesField = 'lenses';
const String extsButtonsField = 'buttons';

// The extension currently being loaded
// This is used for lua functions like deflens and defbutton
String? loadingExtension;


List<LensExtension> lensExtensions = [];


void loadExtensionCode(LuaState lua, String ext, String code) {
  final globalsBefore = luaGlobals(lua);

  loadingExtension = ext;
  final result = luaExecuteCode(lua, code);
  loadingExtension = null;

  if (result is LuaFailure) {
  // ignore: avoid_print
    print('Error loading $ext: ${result.error}');
  }

  // Figure out what new globals the extension defined
  final globalsAfter = luaGlobals(lua);
  final newGlobals = globalsAfter.difference(globalsBefore);

  // Put the new values into their own table
  lua.newTable();
  for (final newGlobal in newGlobals.whereType<LuaString>()) {
    lua.getGlobal(newGlobal.value);
    lua.setField(-2, newGlobal.value);
    // Remove the new variable from global scope
    lua.pushNil();
    lua.setGlobal(newGlobal.value);
  }

  // Put the new table into extensions[name][scope]
  luaSetTableEntry(lua, extsVariable, [ext, extsScopeField]);
}

Future<void> loadExtensions(LuaState lua, Directory rootDir) async {
  final extensionsDir = Directory.fromUri(rootDir.uri.resolve(extDirectory));
  final subDirs = (await extensionsDir.list().toList()).whereType<Directory>();
  final maybeExtensions = (await Future.wait(
      subDirs.map((dir) async {
          final indexFile = File.fromUri(dir.uri.resolve(extIndexFileName));
          if (!(await indexFile.exists())) return null;
          return (dir, await indexFile.readAsString());
      })
  ));

  for (final maybeExt in maybeExtensions) {
    if (maybeExt == null) return;
    final (dir, content) = maybeExt;
    final extName = fileName(dir);
    final codeBlocks = Structure.parse(content).getElements<StructureCode>();

    loadExtensionCode(lua, extName, codeBlocks.map((c) => c.content).join('\n'));
  }
}


LensExtension? getLens(String dir, String name) => (
  lensExtensions
  .where((lens) => lens.name == name && lens.ext == dir)
  .firstOrNull
);
