import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_result.dart';


File? luaCurrentFile;
LuaResult luaExecuteCode(LuaState lua, String code, File? file) {
  final prevFile = luaCurrentFile;
  luaCurrentFile = file;
  try {
    lua.setTop(0);
    lua.loadString(code);
    lua.call(0, 1);
    return LuaSuccess(LuaObject.parse(lua));
  } catch (e) {
    return LuaFailure(e.toString());
  } finally {
    luaCurrentFile = prevFile;
  }
}


void luaPushTableEntry(LuaState lua, String variable, List<String> fields) {
  lua.getGlobal(variable);

  for (final field in fields) {
    lua.getField(-1, field);
    if (lua.isNil(-1)) throw 'No table at $field';

    // Remove the old table
    lua.insert(-2);
    lua.pop(1);
  }
}

void luaGetCreateTables(LuaState lua, String variable, List<String> fields) {
  lua.getGlobal(variable);

  for (final field in fields) {
    // Try getting the value
    lua.getField(-1, field);

    // If its nil, set a new value and push it
    if (lua.isNil(-1)) {
      lua.pop(1);

      // Set the field to a new table
      lua.newTable();
      lua.setField(-2, field);

      // Get the new table
      lua.getField(-1, field);
    }

    // Remove the old table
    lua.insert(-2);
    lua.pop(1);
  }
}

// Put the top object in the stack into the table (and removes it from the stack)
void luaSetTableEntry(LuaState lua, String variable, List<String> fields) {
  luaGetCreateTables(lua, variable, fields.sublist(0, fields.length - 1));

  // State should look like [value, table]
  lua.insert(-2);
  lua.setField(-2, fields.last);
  lua.pop(1);
}

Set<LuaObject> luaGlobals(LuaState lua) {
  lua.pushGlobalTable();
  final table = LuaObject.parse(lua, maxDepth: 1) as LuaTable;
  lua.pop(1);
  return table.value.keys.toSet();
}
