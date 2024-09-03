import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/functions.dart';


const String exportsField = '*exports*';
const String scopeField = '*scope*';


LuaState? _luaState;
LuaState getGlobalLuaState() {
  var lua = _luaState;
  if (lua == null) {
    lua = initializeLuaState();
    _luaState = lua;
  }
  return lua;
}


void _createGlobalTable(LuaState lua, String variable) {
  lua.newTable();
  lua.setGlobal(variable);
}

void _stripLibFunctions(LuaState lua, String lib, {required List<String> keep}) {
  lua.getGlobal(lib);
  if (!lua.isTable(-1)) {
    lua.pop(1);
    return;
  }

  lua.pushNil();
  while (lua.next(-2)) {
    lua.pop(1); // Pop the value
    if (!keep.contains(lua.toStr(-1))) {
      lua.pushValue(-1);
      lua.pushNil();
      // Stack is [lib, key, key, nil]
      lua.setTable(-4);
    }
  }
  lua.pop(1);
}


LuaState initializeLuaState() {
  final lua = LuaState.newState();

  // Load lua libraries
  lua.openLibs();

  // Remove access to the filesystem
  lua.doString('loadfile = nil');
  _stripLibFunctions(lua, 'os', keep: ['clock', 'difftime', 'date', 'time']);
  // The io library doesn't get created by luadardo
  lua.doString('io = {stdout=print}');
  _stripLibFunctions(lua, 'io', keep: ['stdout']);

  // Register dart functions
  registerLuaFunctions(lua, 'App');

  // Initialize global tables
  _createGlobalTable(lua, extsVariable);
  _createGlobalTable(lua, lensesVariable);

  return lua;
}
