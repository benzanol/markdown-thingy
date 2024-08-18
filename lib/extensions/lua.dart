import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_result.dart';


const int luaRegistryIndex = -10000;

final LuaState luaState = _initializeLua();
LuaState _initializeLua() {
  final state = LuaState.newState();
  state.openLibs();
  state.doString('$lensesVariable = {}');
  state.doString('$instancesVariable = {}');
  return state;
}


T luaEval<T>(T Function(LuaState state) fn, {int args = 0}) {
  try {
    luaState.call(args, 1);
    return fn(luaState);
  } finally {
    luaState.setTop(0);
  }
}

LuaResult luaEvalToResult(String code) {
  try {
    luaState.loadString(code);
    return luaEval((state) => LuaSuccess(LuaObject.parse(state)));
  } catch (e) {
    return LuaFailure(e.toString());
  }
}
