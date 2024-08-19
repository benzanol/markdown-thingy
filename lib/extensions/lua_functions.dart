import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_utils.dart';
import 'package:notes/extensions/to_lua.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/structure.dart';


// Functions which manually push their output onto the stack, and return the number of outputs
final rawFunctions = <String, int Function(LuaState)> {
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
    final ext = loadingExtension;
    if (ext == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 2);
    final name = ensureLuaString(LuaObject.parse(lua, index: -2));
    final table = ensureLuaTable(LuaObject.parse(lua, index: -1));

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field], LuaType.luaFunction, field: field);
    }

    // Get the name
    final lens = LensExtension(ext: ext, name: name);
    lensTypes.add(lens);

    // Add it to the lua table
    luaSetTableEntry(lua, extsVariable, lens.lensFields);
  },
};

void registerLuaFunctions(LuaState lua, String tableName) {
  // Table to hold all of the dart functions
  lua.newTable();

  // Add raw functions to the table
  for (final rawFn in rawFunctions.entries) {
    lua.pushDartFunction(rawFn.value);
    lua.setField(-2, rawFn.key);
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
