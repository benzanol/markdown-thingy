import 'package:lua_dardo/lua.dart';


List<LuaObject> parseStack(LuaState lua) {
  final length = lua.getTop();
  return List.generate(length, (idx) => LuaObject.parse(lua, index: idx - length));
}

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

  static LuaObject parse(LuaState lua, {int index = -1}) {
    if (lua.isNil(index)) {
      return LuaNil();
    } else if (lua.isInteger(index)) {
      return LuaNumber(lua.toInteger(index));
    } else if (lua.isNumber(index)) {
      return LuaNumber(lua.toNumber(index));
    } else if (lua.isBoolean(index)) {
      return LuaBoolean(lua.toBoolean(index));
    } else if (lua.isTable(index)) {
      Map<LuaObject, LuaObject> table = {};
      // When lua iterates through tables, it expects the stack to look like [..., table, prevKey].
      // Start with a nil key to indicate that the iteration hasn't started
      lua.pushNil();
      while (lua.next(index - 1)) {
        LuaObject value = LuaObject.parse(lua);
        lua.pop(1);  // Pop the value, keep the key for the next iteration
        LuaObject key = LuaObject.parse(lua);
        table[key] = value;
      }
      return LuaTable(table);
    }   else if (lua.isString(index)) {
      return LuaString(lua.toStr(index)!);
    } else {
      return LuaOther(lua.type(index).toString());
    }
  }
}

class LuaNil extends LuaObject {
  @override final value = null;

  @override
  String toString() => 'nil';
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

class LuaOther extends LuaObject {
  LuaOther(this.type);
  final String type;
  @override final dynamic value = null;

  @override
  String toString() => '<$type>';
}
