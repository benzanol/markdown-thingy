import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lua_object.dart';


abstract class ToJson {
  dynamic toJson();
}

LuaObject toLua(dynamic object) => (
  object is LuaObject ? object
  : object == null ? LuaNil()
  : object is num ? LuaNumber(object)
  : object is bool ? LuaBoolean(object)
  : object is String ? LuaString(object)
  : object is List ? LuaTable(Map.fromIterables(
      List.generate(object.length, (idx) => LuaNumber(idx+1)),
      object.map(toLua),
  ))
  : object is Map ? LuaTable(Map.fromEntries(
      object.entries.map((e) => MapEntry(toLua(e.key), toLua(e.value))),
  ))
  : object is ToJson ? toLua(object.toJson())
  : (throw 'Invalid json type: ${object.runtimeType}')
);

void luaPush(LuaState lua, dynamic object) {
  toLua(object).put(lua);
}
