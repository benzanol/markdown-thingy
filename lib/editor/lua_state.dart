import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/extensions/lua_functions.dart';


final LuaState _luaState = initializeLuaState();
LuaState getGlobalLuaState() => _luaState;

LuaState initializeLuaState() {
  final lua = LuaState.newState();

  // Load lua libraries
  lua.openLibs();
  // Remove access to os and io libs
  lua.doString('os = nil');
  lua.doString('io = nil');

  // Register dart functions
  registerLuaFunctions(lua, 'Lib');

  // Load custom code
  lua.doString('$extsVariable = {}');
  lua.doString('$lensesVariable = {}');
  lua.doFile('lua/ui.lua');

  return lua;
}
