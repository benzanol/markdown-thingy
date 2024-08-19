import 'package:lua_dardo/lua.dart';


List<LuaObject> parseStack(LuaState lua) {
  final length = lua.getTop();
  return List.generate(length, (idx) => LuaObject.parse(lua, index: idx - length));
}

abstract class LuaObject {
  dynamic get value;
  @override String toString() => value.toString();

  LuaType get type;
  void put(LuaState lua);

  @override
  bool operator ==(Object other) => (
    other is LuaObject
    && other.runtimeType == runtimeType
    && other.value == value
  );

  @override
  int get hashCode => value.hashCode;

  static LuaObject parse(LuaState lua, {int index = -1, int? maxDepth}) {
    final nextMaxDepth = maxDepth == null ? null : maxDepth - 1;

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
      if (maxDepth == 0) return LuaTable(table);

      // When lua iterates through tables, it expects the stack to look like [table, ..., prevKey],
      // where table is at position index-1 (since it was at index before adding the key.)
      // Start with a nil key to indicate that the iteration hasn't started.
      lua.pushNil();
      while (lua.next(index - 1)) {
        LuaObject value = LuaObject.parse(lua, maxDepth: nextMaxDepth);
        lua.pop(1);  // Pop the value, keep the key for the next iteration
        LuaObject key = LuaObject.parse(lua, maxDepth: nextMaxDepth);
        table[key] = value;
      }
      return LuaTable(table);
    }   else if (lua.isString(index)) {
      return LuaString(lua.toStr(index)!);
    } else {
      return LuaOther(lua.type(index));
    }
  }
}

class LuaNil extends LuaObject {
  @override final value = null;

  @override LuaType get type => LuaType.luaNil;
  @override void put(LuaState lua) => lua.pushNil();
  @override String toString() => 'nil';
}

class LuaString extends LuaObject {
  LuaString(this.value);
  @override final String value;

  @override LuaType get type => LuaType.luaString;
  @override void put(LuaState lua) => lua.pushString(value);
  @override String toString() => '"$value"';
}

class LuaNumber extends LuaObject {
  LuaNumber(this.value);
  @override final num value;

  @override
  LuaType get type => LuaType.luaNumber;

  @override
  void put(LuaState lua) {
    final n = value;
    if (n is int) {
      lua.pushInteger(n);
    } else {
      lua.pushNumber(n.toDouble());
    }
  }
}

class LuaBoolean extends LuaObject {
  LuaBoolean(this.value);
  @override final bool value;

  @override LuaType get type => LuaType.luaBoolean;
  @override void put(LuaState lua) => lua.pushBoolean(value);
}

class LuaTable extends LuaObject {
  LuaTable(this.value);
  @override final Map<LuaObject, LuaObject> value;

  LuaObject? operator [](field) => (
    field is num ? value[LuaNumber(field)]
    : field is String ? value[LuaString(field)]
    : null
  );

  @override
  LuaType get type => LuaType.luaTable;

  @override
  void put(LuaState lua) {
    lua.newTable();
    for (final entry in value.entries) {
      entry.key.put(lua);
      entry.value.put(lua);
      lua.setTable(-3);
    }
  }

  Iterable<LuaObject> get listValues => value.entries
  .where((e) => e.key is LuaNumber)
  .map((e) => e.value);
}

class LuaOther extends LuaObject {
  LuaOther(this.type);
  @override final LuaType type;
  @override final dynamic value = null;

  @override
  String toString() => '<$type>';

  @override
  void put(LuaState lua) => lua.pushNil();
}
