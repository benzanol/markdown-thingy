import 'package:lua_dardo/lua.dart';

abstract class LuaObject {
  dynamic get value;
  @override String toString() => value.toString();

  @override
  bool operator ==(Object other) => (
    other is LuaObject
    && other.runtimeType == runtimeType
    && other.value == value
  );

  @override
  int get hashCode => value.hashCode;

  static LuaObject parse(LuaState lua) {
    if (lua.isInteger(-1)) {
      return LuaNumber(lua.toInteger(-1));
    } else if (lua.isNumber(-1)) {
      return LuaNumber(lua.toNumber(-1));
    } else if (lua.isBoolean(-1)) {
      return LuaBoolean(lua.toBoolean(-1));
    } else if (lua.isTable(-1)) {
      Map<LuaObject, LuaObject> table = {};
      // When lua iterates through tables, it expects the stack to look like [..., table, prevKey].
      // Start with a nil key to indicate that the iteration hasn't started
      lua.pushNil();
      while (lua.next(-2)) {
        LuaObject value = LuaObject.parse(lua);
        lua.pop(1);  // Pop the value, keep the key for the next iteration
        LuaObject key = LuaObject.parse(lua);
        table[key] = value;
      }
      return LuaTable(table);
    }   else if (lua.isString(-1)) {
      return LuaString(lua.toStr(-1)!);
    } else {
      throw Exception('Unsupported Lua type');
    }
  }
}

class LuaString extends LuaObject {
  LuaString(this.value);
  @override final String value;

  @override
  String toString() => '"$value"';
}

class LuaNumber extends LuaObject {
  LuaNumber(this.value);
  @override final num value;
}

class LuaBoolean extends LuaObject {
  LuaBoolean(this.value);
  @override final bool value;
}

class LuaTable extends LuaObject {
  LuaTable(this.value);
  @override final Map<LuaObject, LuaObject> value;

  Iterable<LuaObject> get listValues => value.entries
  .where((e) => e.key is LuaNumber)
  .map((e) => e.value);
}
