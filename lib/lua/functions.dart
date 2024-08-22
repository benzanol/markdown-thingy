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

  if (!file.path.startsWith(repoRootDirectory.path)) throw 'File $relative is outside of the repo';
  if (!file.existsSync()) throw 'File $relative does not exist';

  return file;
}
Directory _resolveDir(String relative) {
  final currentDir = luaCurrentFile?.parent ?? repoRootDirectory;
  final dir = Directory.fromUri(currentDir.uri.resolve(relative));

  if (!dir.path.startsWith(repoRootDirectory.path)) throw 'Directory $relative is outside of the repo';
  if (!dir.existsSync()) throw 'File $relative does not exist';

  return dir;
}



// Functions which manually push their output onto the stack, and return the number of outputs
final pushFunctions = <String, int Function(LuaState)> {
  'import': (lua) {
    ensureArgCount(lua, 1);
    final extName = ensureLuaString(LuaObject.parse(lua, index: 1), 'extension');

    // Push the scope onto the stack
    luaPushTableEntry(lua, extsVariable, [extName, extsScopeField]);
    return 1;
  },

  'parse_directory': (lua) {
    ensureArgCount(lua, 1, max: 3);
    final relativeDir = ensureLuaString(LuaObject.parse(lua, index: 1), 'directory');
    final fn = ensureLuaTypeOrNone(LuaObject.parse(lua, index: 2), LuaType.luaFunction, 'modifier');
    final err = ensureLuaTypeOrNone<LuaBoolean>(LuaObject.parse(lua, index: 3), LuaType.luaBoolean, 'err');

    // Get a list of structures
    final dir = _resolveDir(relativeDir);
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('md'));
    final structs = files.map((f) => (f, Structure.parse(f.readAsStringSync())));

    // If there is no function, return the list of structs
    if (fn == null) {
      toLua(structs.map((tup) => tup.$2).toList()).put(lua);
      return 1;
    }

    // Create a table for the structs, and then push the function results into the table
    lua.newTable();
    for (final (file, struct) in structs) {
      // Call the function with the struct as the argument
      lua.pushValue(2);
      toLua(struct).put(lua);
      final status = lua.pCall(1, 1, 0);

      // The stack looks like [dir, function, table, result/error]
      if (status == ThreadStatus.luaOk) {
        // Add the result to the table
        lua.pushString(fileName(file));
        lua.insert(-2);
        lua.setTable(-3);
      } else if (err == LuaBoolean(true)) {
        // Throw the error if the user specified not to ignore errors
        throw lua.toStr(-1)!;
      } else {
        // Pop the error message
        lua.pop(1);
      }
    }

    return 1;
  },
};

// Functions which return their output
final returnFunctions = <String, dynamic Function(LuaState)>{
  'print_stack': (lua) {
    // ignore: avoid_print
    print('STACK: ${parseStack(lua)}');
  },

  'parse_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua, index: 1), 'string');
    return Structure.parse(content);
  },
  'to_markdown': (lua) {
    ensureArgCount(lua, 1);
    final structure = ensureLuaTable(LuaObject.parse(lua, index: 1), 'structure');
    return Structure.fromLua(structure).toText();
  },

  'deflens': (lua) {
    final extDir = loadingExtension;
    if (extDir == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 2);
    final name = ensureLuaString(LuaObject.parse(lua, index: 1), 'name');
    final table = ensureLuaTable(LuaObject.parse(lua, index: 2), 'functions');

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field] ?? LuaNil(), LuaType.luaFunction, 'functions.$field');
    }

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name);
    lensTypes.add(lens);

    // Add it to the lua table
    luaSetTableEntry(lua, extsVariable, lens.lensFields);
  },

  'read_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    return file.readAsStringSync();
  },
  'parse_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    if (!file.path.endsWith('.md')) throw 'Can only parse a markdown (.md) file';
    return Structure.parse(file.readAsStringSync());
  },
  'load_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));

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
