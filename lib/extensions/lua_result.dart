import 'package:flutter/material.dart';


abstract class LuaResult {
  Widget widget();
}

class LuaSuccess extends LuaResult {
  LuaSuccess(this.value);
  final Object value;

  @override
  Widget widget() => Text(value.toString());
}

class LuaFailure extends LuaResult {
  LuaFailure(this.error);
  final String error;

  @override
  Widget widget() => Text(error, style: const TextStyle(color: Colors.red));
}
