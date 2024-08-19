import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/main.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/structure.dart';


// Functions which manually push their output onto the stack, and return the number of outputs
final pushFunctions = <String, int Function(LuaState)> {
  'import': (lua) {
    ensureArgCount(lua, 1);
    final extName = ensureLuaString(LuaObject.parse(lua));

    // Push the scope onto the stack
    luaPushTableEntry(lua, extsVariable, [extName, extsScopeField]);
    return 1;
  },
};

// Functions which return their output
final returnFunctions = <String, dynamic Function(LuaState)>{
  'loadfile': (lua) {
    final currentDir = luaCurrentFile?.parent;
    if (currentDir == null) throw 'loadfile can only be used in extensions';

    ensureArgCount(lua, 1);
    final relativePath = ensureLuaString(LuaObject.parse(lua));
    final fromRepoRoot = currentDir.uri.resolve(relativePath);

    // Check the file type
    final isMarkdown =
    relativePath.endsWith('.md') ? true
    : relativePath.endsWith('.lua') ? false
    : (throw 'Can only load a lua (.lua) or markdown (.md) file');

    // Check if the file exists
    final file = File.fromUri(repoRootDirectory.uri.resolveUri(fromRepoRoot));
    if (!file.existsSync()) throw 'File $fromRepoRoot does not exist';

    // Parse the code from the file
    final contents = file.readAsStringSync();
    final code = !isMarkdown ? contents : (
      Structure.parse(contents).getElements<StructureCode>().map((c) => c.content).join('\n')
    );

    final result = luaExecuteCode(lua, code, file);
    if (result is LuaFailure) throw result.error;
    if (result is LuaSuccess) return result.value;
  },
  'parse_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua));
    return Structure.parse(content);
  },
  'load_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua));

    final structure = Structure.parse(content);
    final codeBlocks = structure.getElements<StructureCode>();
    lua.doString(codeBlocks.map((block) => block.content).join('\n'));
  },
  'deflens': (lua) {
    final extDir = loadingExtension;
    if (extDir == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 2);
    final name = ensureLuaString(LuaObject.parse(lua, index: -2));
    final table = ensureLuaTable(LuaObject.parse(lua, index: -1));

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field], LuaType.luaFunction, field: field);
    }

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name);
    lensTypes.add(lens);

    // Add it to the lua table
    luaSetTableEntry(lua, extsVariable, lens.lensFields);
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



String luaTypeName(LuaType? type) => type == null ? 'nil' : type.name.substring(3).toLowerCase();

void ensureArgCount(LuaState lua, int min, {int? max}) {
  final count = lua.getTop();
  if (count >= min && count <= (max ?? min)) return;
  final argsStr = max == null ? '$min' : '$min-$max';
  throw 'Expected $argsStr arguments, but found $count';
}

T ensureLuaType<T extends LuaObject>(LuaObject? obj, LuaType type, {String? field}) {
  if (obj is T && obj.type == type) return obj;
  final fieldStr = field == null ? '' : ' at "$field"';
  throw 'Expected ${luaTypeName(type)}$fieldStr, but found ${luaTypeName(obj?.type)}';
}

LuaTable ensureLuaTable(LuaObject? obj, {String? field}) => (
  ensureLuaType<LuaTable>(obj, LuaType.luaTable, field: field)
);

String ensureLuaString(LuaObject? obj, {String? field}) => (
  ensureLuaType<LuaString>(obj, LuaType.luaString, field: field).value
);

num ensureLuaNumber(LuaObject? obj, {String? field}) => (
  ensureLuaType<LuaNumber>(obj, LuaType.luaNumber, field: field).value
);
