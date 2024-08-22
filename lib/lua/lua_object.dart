import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/to_lua.dart';


// Lua variable used to store parsed tables to allow for circular references
const tableCacheVariable = '*table-cache*';


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

  static LuaObject parse(LuaState lua, {
      int index = -1,
      int? maxDepth,
      List<LuaTable>? tableCache,
  }) {
    final nextMaxDepth = maxDepth == null ? null : maxDepth - 1;

    // Reset the table cache
    if (tableCache == null) {
      tableCache = [];
      lua.newTable();
      lua.setGlobal(tableCacheVariable);
    }

    if (lua.isNil(index)) {
      return LuaNil();
    } else if (lua.isInteger(index)) {
      return LuaNumber(lua.toInteger(index));
    } else if (lua.isNumber(index)) {
      return LuaNumber(lua.toNumber(index));
    } else if (lua.isBoolean(index)) {
      return LuaBoolean(lua.toBoolean(index));
    } else if (lua.isTable(index)) {
      if (maxDepth == 0) return LuaTable({});

      // Check if this is in the table cache
      lua.pushValue(index);
      lua.getGlobal(tableCacheVariable);
      lua.insert(-2);
      lua.getTable(-2);
      // Stack looks like [..., tableCache, index?]
      final cacheIndex = lua.toIntegerX(-1);
      lua.pop(2);
      if (cacheIndex != null) {
        return tableCache[cacheIndex];
      }

      // Add this table to the table cache
      lua.pushValue(index);
      lua.getGlobal(tableCacheVariable);
      lua.insert(-2);
      lua.pushInteger(tableCache.length);
      // Stack looks like [..., tableCache, table, index]
      lua.setTable(-3);
      lua.pop(1);

      final table = LuaTable({});
      tableCache.add(table);

      // When lua iterates through tables, it expects the stack to look like [table, ..., prevKey],
      // where table is at position index-1 (since it was at index before adding the key.)
      // Start with a nil key to indicate that the iteration hasn't started.
      lua.pushNil();
      final indexNow = index < 0 ? index - 1 : index;
      while (lua.next(indexNow)) {
        LuaObject value = LuaObject.parse(lua, maxDepth: nextMaxDepth, tableCache: tableCache);
        lua.pop(1);  // Pop the value, keep the key for the next iteration
        LuaObject key = LuaObject.parse(lua, maxDepth: nextMaxDepth, tableCache: tableCache);
        table.value[key] = value;
      }

      return table;
    } else if (lua.isString(index)) {
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

  @override
  String toString() {
    const String indent = '    ';
    final entries = value.entries.map((e) {
        final valueStr = e.value.toString().replaceAll('\n', '\n$indent');
        return '$indent${e.key}: $valueStr,';
    });
    return '{\n${entries.join("\n")}\n}';
  }

  LuaObject? operator [](field) => (
    field is num ? value[LuaNumber(field)]
    : field is String ? value[LuaString(field)]
    : null
  );
  void operator []=(field, obj) => (
    field is num ? value[LuaNumber(field)] = toLua(obj)
    : field is String ? value[LuaString(field)] = toLua(obj)
    : throw 'Invalid table key: $field'
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
  String toString() => '<${luaTypeName(type)}>';

  @override
  void put(LuaState lua) => lua.pushNil();
}
