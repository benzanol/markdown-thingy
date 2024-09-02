import 'dart:math';

import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_ui.dart';
import 'package:notes/lua/utils.dart';


const String toStateField = 'parse';
const String toTextField = 'format';
const String toUiField = 'render';

const String lensesVariable = '*lenses*';
const String lensesStateField = 'state';
const String lensesUiField = 'ui';


final Set<LensExtension> lensTypes = {};
LensExtension? getLens(String ext, String name) => (
  lensTypes.where((l) => l.ext == ext && l.name == name).firstOrNull
);


class LensExtension {
  LensExtension({required this.ext, required this.name});
  final String ext;
  final String name;

  List<String> get lensFields => [ext, extsLensesField, name];

  int generateState(LuaState lua, String content) {
    print('Creating new state $ext/$name');
    lua.setTop(0);

    // Call the toState function on the content
    luaPushTableEntry(lua, extsVariable, [...lensFields, toStateField]);
    lua.pushString(content);
    lua.call(1, 1);

    // Push the result into the instances table at index `randomId`
    final randomId = Random().nextInt(1000000000);
    luaSetTableEntry(lua, lensesVariable, [randomId.toString(), lensesStateField]);
    return randomId;
  }

  String generateText(LuaState lua, int id) {
    lua.setTop(0);

    // Call the text function on the state
    luaPushTableEntry(lua, extsVariable, [...lensFields, toTextField]);
    luaPushTableEntry(lua, lensesVariable, [id.toString(), lensesStateField]);
    lua.call(1, 1);

    return lua.toStr(-1)!;
  }

  LuaUi generateUi(LuaState lua, int id) {
    lua.setTop(0);

    // Call the ui function on the state
    luaPushTableEntry(lua, extsVariable, [...lensFields, toUiField]);
    luaPushTableEntry(lua, lensesVariable, [id.toString(), lensesStateField]);
    lua.call(1, 1);

    // Copy the value reference, and put it into the instances table
    lua.pushValue(-1);
    luaSetTableEntry(lua, lensesVariable, [id.toString(), lensesUiField]);

    return LuaUi.parse(LuaObject.parse(lua));
  }
}
