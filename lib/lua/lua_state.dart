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


void _loadLuaLibrary(LuaState lua, String name) {
  lua.setTop(0);
  lua.loadString('$name = require "$name"');
  final result = lua.pCall(0, 1, 0);
  if (result != ThreadStatus.luaOk) {
    // ignore: avoid_print
    print('Error loading library $name: ${lua.toStr(-1)}');
    return;
  }
}

void _initializeGlobalTable(LuaState lua, String variable) {
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
  _stripLibFunctions(lua, 'io', keep: []);
  lua.doString('io = {stdout=print}');

  lua.doString('package.path = "./lua/?.lua"');
  _loadLuaLibrary(lua, 'debug');
  _loadLuaLibrary(lua, 'Ui');
  _loadLuaLibrary(lua, 'Pl');

  // Register dart functions
  registerLuaFunctions(lua, 'Lib');
  _loadLuaLibrary(lua, 'Lib');

  // Initialize global tables
  _initializeGlobalTable(lua, extsVariable);
  _initializeGlobalTable(lua, lensesVariable);

  return lua;
}
