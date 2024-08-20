import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/structure/structure.dart';


const String extDirectory = 'extensions';
const String extIndexFileName = 'index.md';
const String extsVariable = '__extensions__';

const String extsScopeField = 'scope';
const String extsLensesField = 'lenses';
const String extsButtonsField = 'buttons';

// The extension currently being loaded
// This is used for lua functions like deflens and defbutton
Directory? loadingExtension;


void runExtensionCode(LuaState lua, Directory extDir, String code) {
  final extName = fileName(extDir);
  final indexFile = File.fromUri(extDir.uri.resolve(extIndexFileName));

  final globalsBefore = luaGlobals(lua);

  loadingExtension = extDir;
  final result = luaExecuteFile(lua, code, indexFile);
  loadingExtension = null;

  if (result is LuaFailure) {
    // ignore: avoid_print
    print('Error loading $extName: ${result.error}');
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
  luaSetTableEntry(lua, extsVariable, [extName, extsScopeField]);
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
    final (extDir, content) = maybeExt;
    runExtensionCode(lua, extDir, Structure.parse(content).getLuaCode());
  }
}
