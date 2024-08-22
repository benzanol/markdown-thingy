import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/lua_object.dart';


Set<LuaObject> luaGlobals(LuaState lua) {
  lua.pushGlobalTable();
  final table = LuaObject.parse(lua, maxDepth: 1) as LuaTable;
  lua.pop(1);
  return table.value.keys.toSet();
}

// Run luaFn, and then push the created scope onto the stack
T saveLuaScope<T>(LuaState lua, T Function(LuaState) luaFn) {
  final globalsBefore = luaGlobals(lua);

  final output = luaFn(lua);

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

  return output;
}
