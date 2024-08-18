import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_result.dart';


const int luaRegistryIndex = -10000;

final LuaState luaState = _initializeLua();
LuaState _initializeLua() {
  final lua = LuaState.newState();
  lua.openLibs();
  lua.doFile('lua/ui.lua');
  lua.doString('$lensesVariable = {}');
  lua.doString('$instancesVariable = {}');
  return lua;
}


LuaResult luaExecuteCode(String code) {
  try {
    luaState.setTop(0);
    luaState.loadString(code);
    luaState.call(0, 1);
    return LuaSuccess(LuaObject.parse(luaState));
  } catch (e) {
    return LuaFailure(e.toString());
  }
}

void luaLoadTableEntry(String variable, List<String> fields) {
  luaState.getGlobal(variable);

  for (final field in fields) {
    luaState.getField(-1, field);
    // Remove the old table
    luaState.insert(-2);
    luaState.pop(1);
  }
}

void luaGetCreateTables(String variable, List<String> fields) {
  luaState.getGlobal(variable);

  for (final field in fields) {
    // Try getting the value
    luaState.getField(-1, field);

    // If its nil, set a new value and push it
    if (luaState.isNil(-1)) {
      luaState.pop(1);

      // Set the field to a new table
      luaState.newTable();
      luaState.setField(-2, field);

      // Get the new table
      luaState.getField(-1, field);
    }

    // Remove the old table
    luaState.insert(-2);
    luaState.pop(1);
  }
}

// Put the top object in the stack into the table (and removes it from the stack)
void luaSetTableEntry(String variable, List<String> fields) {
  luaGetCreateTables(variable, fields.sublist(0, fields.length - 1));

  // State should look like [value, table]
  luaState.insert(-2);
  luaState.setField(-2, fields.last);
  luaState.pop(1);
}
