import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/lua_object.dart';


String luaTypeName(LuaType? type) => type == null ? 'nil' : type.name.substring(3).toLowerCase();

void ensureArgCount(LuaState lua, int min, {int? max}) {
  final count = lua.getTop();
  if (count < min || count > (max ?? min)) {
    final argsStr = max == null ? '$min' : '$min-$max';
    throw 'Expected $argsStr arguments, but found $count';
  }
}


T ensureLuaType<T extends LuaObject>(LuaObject obj, LuaType type, String field) {
  if (obj is T && obj.type == type) return obj;
  throw 'Expected ${luaTypeName(type)} at "$field", but found $obj';
}

LuaTable ensureLuaTable(LuaObject obj, String field) => (
  ensureLuaType<LuaTable>(obj, LuaType.luaTable, field)
);

String ensureLuaString(LuaObject obj, String field) => (
  ensureLuaType<LuaString>(obj, LuaType.luaString, field).value
);

num ensureLuaNumber(LuaObject obj, String field) => (
  ensureLuaType<LuaNumber>(obj, LuaType.luaNumber, field).value
);


T? ensureLuaTypeOrNone<T extends LuaObject>(LuaObject obj, LuaType type, String field) {
  if (obj.type == LuaType.luaNone) return null;
  if (obj is T && obj.type == type) return obj;
  throw 'Expected ${luaTypeName(type)}? at "$field", but found ${luaTypeName(obj.type)}';
}
