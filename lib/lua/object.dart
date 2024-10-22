import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/ensure.dart';


sealed class LuaObject {
  dynamic get value;
  @override String toString() => value.toString();

  static LuaObject fromJson(dynamic obj) => _jsonToLua(obj);

  LuaType get type;
  bool get isTruthy => true;

  @override
  bool operator ==(Object other) => (
    other is LuaObject
    && other.runtimeType == runtimeType
    && other.value == value
  );

  @override
  int get hashCode => value.hashCode;
}

class LuaNil extends LuaObject {
  @override final value = null;

  @override LuaType get type => LuaType.luaNil;
  @override bool get isTruthy => false;
  @override String toString() => 'nil';
}

class LuaString extends LuaObject {
  LuaString(this.value);
  @override final String value;

  @override LuaType get type => LuaType.luaString;
  @override String toString() => '"$value"';
}

class LuaNumber extends LuaObject {
  LuaNumber(this.value);
  @override final num value;

  @override
  LuaType get type => LuaType.luaNumber;
}

class LuaBoolean extends LuaObject {
  LuaBoolean(this.value);
  @override final bool value;

  @override LuaType get type => LuaType.luaBoolean;
  @override bool get isTruthy => value;
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
    field is num ? value[LuaNumber(field)] = LuaObject.fromJson(obj)
    : field is String ? value[LuaString(field)] = LuaObject.fromJson(obj)
    : throw 'Invalid table key: $field'
  );

  @override
  LuaType get type => LuaType.luaTable;

  Iterable<LuaObject> get listValues => value.entries
  .where((e) => e.key is LuaNumber)
  .map((e) => e.value);
}

class LuaOther extends LuaObject {
  LuaOther(this.type);
  @override final LuaType type;
  @override final dynamic value = null;

  @override bool get isTruthy => type != LuaType.luaNone && type != LuaType.luaNil;

  @override
  String toString() => '<${luaTypeName(type)}>';
}


abstract class ToJson {
  dynamic toJson();
}

LuaObject _jsonToLua(dynamic obj) => (
  obj is LuaObject ? obj
  : obj is ToJson ? _jsonToLua(obj.toJson())
  : obj == null ? LuaNil()
  : obj is num ? LuaNumber(obj)
  : obj is bool ? LuaBoolean(obj)
  : obj is String ? LuaString(obj)
  : obj is List ? LuaTable(Map.fromIterables(
      List.generate(obj.length, (idx) => LuaNumber(idx+1)),
      obj.map(_jsonToLua),
  ))
  : obj is Map ? LuaTable(Map.fromEntries(
      obj.entries.map((e) => MapEntry(_jsonToLua(e.key), _jsonToLua(e.value))),
  ))
  : (throw 'Invalid json type: ${obj.runtimeType}')
);
