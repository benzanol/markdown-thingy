import 'package:flutter/material.dart';
import 'package:notes/lua/lua_object.dart';


abstract class LuaResult {
  Widget widget();
}

class LuaSuccess extends LuaResult {
  LuaSuccess(this.value);
  final LuaObject value;

  @override
  Widget widget() => Text(value.toString());

  @override
  String toString() => 'LuaSuccess($value)';
}

class LuaFailure extends LuaResult {
  LuaFailure(this.error);
  final String error;

  @override
  Widget widget() => Text(error, style: const TextStyle(color: Colors.red));

  @override
  String toString() => 'LuaFailure($error)';
}
