import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_result.dart';
import 'package:notes/extensions/lua_ui.dart';


const String luaVariable = 'output';
final LuaState _luaState = createState();

LuaState createState() {
  final state = LuaState.newState();
  state.openLibs();
  return state;
}

LuaResult executeLua(String code) {
  try {
    _luaState.doString('$luaVariable = nil');

    _luaState.doString(code);
    final result = LuaUi.parse(LuaObject.parse(_luaState));
    _luaState.pop(1);  // Remove the result from the stack

    return LuaSuccess(result);

  } catch (e) {
    return LuaFailure(e.toString());
  }
}
