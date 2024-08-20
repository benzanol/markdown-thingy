import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/main.dart';
import 'package:notes/structure/structure.dart';


File _resolveFile(String relative) {
  final currentDir = luaCurrentFile?.parent ?? repoRootDirectory;
  final file = File.fromUri(currentDir.uri.resolve(relative));

  if (!file.path.startsWith(repoRootDirectory.path)) {
    throw 'File $relative is outside of the repo';
  }
  if (!file.existsSync()) throw 'File $relative does not exist';

  return file;
}


// Functions which manually push their output onto the stack, and return the number of outputs
final pushFunctions = <String, int Function(LuaState)> {
  'import': (lua) {
    ensureArgCount(lua, 1);
    final extName = ensureLuaString(LuaObject.parse(lua), 'extension');

    // Push the scope onto the stack
    luaPushTableEntry(lua, extsVariable, [extName, extsScopeField]);
    return 1;
  },
};

// Functions which return their output
final returnFunctions = <String, dynamic Function(LuaState)>{
  'parse_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua), 'string');
    return Structure.parse(content);
  },
  'deflens': (lua) {
    final extDir = loadingExtension;
    if (extDir == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 2);
    final name = ensureLuaString(LuaObject.parse(lua, index: -2), 'name');
    final table = ensureLuaTable(LuaObject.parse(lua, index: -1), 'functions');

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field], LuaType.luaFunction, 'functions.$field');
    }

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name);
    lensTypes.add(lens);

    // Add it to the lua table
    luaSetTableEntry(lua, extsVariable, lens.lensFields);
  },

  'read_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua), 'file'));
    return file.readAsStringSync();
  },
  'parse_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua), 'file'));
    if (!file.path.endsWith('.md')) throw 'Can only parse a markdown (.md) file';
    return Structure.parse(file.readAsStringSync());
  },
  'load_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua), 'file'));

    // Check the file type
    final isMarkdown =
    file.path.endsWith('.md') ? true
    : file.path.endsWith('.lua') ? false
    : (throw 'Can only load a lua (.lua) or markdown (.md) file');

    // Parse the code from the file
    final contents = file.readAsStringSync();
    final code = isMarkdown ? Structure.parse(contents).getLuaCode() : contents;

    final result = luaExecuteFile(lua, code, file);
    if (result is LuaFailure) throw result.error;
    if (result is LuaSuccess) return result.value;
  },
};

void registerLuaFunctions(LuaState lua, String tableName) {
  // Table to hold all of the dart functions
  lua.newTable();

  // Add raw functions to the table
  for (final pushFn in pushFunctions.entries) {
    lua.pushDartFunction(pushFn.value);
    lua.setField(-2, pushFn.key);
  }

  // Add returning functions to the table
  for (final returnFn in returnFunctions.entries) {
    lua.pushDartFunction((LuaState lua) {
        final output = returnFn.value(lua);
        toLua(output).put(lua);
        return 1;
    });
    lua.setField(-2, returnFn.key);
  }

  // Store the table in the specified name
  lua.setGlobal(tableName);
}
