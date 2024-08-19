import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:notes/lua/lua_object.dart';


File? luaCurrentFile;
LuaResult luaExecuteFile(LuaState lua, String code, File file) {
  final prevFile = luaCurrentFile;
  luaCurrentFile = file;
  try {
    lua.setTop(0);
    lua.loadString(code);
    lua.call(0, 1);
    return LuaSuccess(LuaObject.parse(lua));
  } catch (e) {
    return LuaFailure(e.toString());
  } finally {
    luaCurrentFile = prevFile;
  }
}


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
