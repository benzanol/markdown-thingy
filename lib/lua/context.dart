import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/init.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/result.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/lua/ui.dart';


final LuaState _globalLuaState = createLuaState();

class LuaContext {
  static LuaContext? current;

  final LuaState _lua;
  final BuildContext context;
  final NoteHandlerState handler;
  final Directory location;
  final Directory? ext;

  LuaContext(this._lua, this.handler, this.context, {required this.location, this.ext});
  LuaContext.global(this.handler, this.context, {Directory? location, this.ext})
  : _lua = _globalLuaState, location = location ?? handler.repoRoot;

  LuaContext inDir(Directory d) => LuaContext(_lua, handler, context, location: d, ext: ext);
  LuaContext inExt(Directory d) => LuaContext(_lua, handler, context, location: d, ext: d);


  int stackSize() => _lua.getTop();

  void push(dynamic jsony) => toLua(jsony).put(_lua);

  LuaObject object(int index) => LuaObject.parse(_lua, index: index);

  List<LuaObject> stack() {
    final length = _lua.getTop();
    return List.generate(length, (idx) => object(idx - length));
  }


  void contextCall(int nargs, int nresults) {
    final oldCurrent = LuaContext.current;
    LuaContext.current = this;
    try {
      _lua.call(nargs, nresults);
    } finally {
      LuaContext.current = oldCurrent;
    }
  }

  void executeOrError({String? code, int? nargs}) {
    if (code != null) {
      _lua.loadString(code);
      contextCall(0, 1);
    } else {
      contextCall(nargs ?? 0, 1);
    }
  }

  LuaResult executeResult({String? code, int? nargs}) {
    try {
      executeOrError(code: code, nargs: nargs);
      return LuaSuccess(object(-1));
    } catch (e) {
      return LuaFailure(e.toString());
    }
  }


  String resolvePath(String relative) {
    final path = (
      relative.startsWith('~/') ? handler.repoRoot.uri.resolve(relative.substring(2)).path
      : File(relative).isAbsolute ? relative
      : location.uri.resolve(relative).path
    );

    if (!path.startsWith(handler.repoRoot.path)) {
      throw 'File $relative is outside of the repo';
    }
    return path;
  }

  File resolveExistingFile(String relative, {bool create = false}) {
    final file = File(resolvePath(relative));
    final exists = file.existsSync();

    if (!exists && create) {
      file.createSync();
    } else if (!exists) {
      throw 'File $relative does not exist';
    }
    return file;
  }

  Directory resolveExistingDir(String relative) {
    final dir = Directory(resolvePath(relative));
    if (!dir.existsSync()) throw 'Directory $relative does not exist';
    return dir;
  }


  void pushTableEntry(String variable, List<dynamic> fields) {
    _lua.getGlobal(variable);

    for (final field in fields) {
      if (field is String) {
        _lua.pushString(field);
      } else if (field is int) {
        _lua.pushInteger(field);
      } else {
        throw 'Invalid field type: $field';
      }
      _lua.getTable(-2);

      if (_lua.isNil(-1)) {
        throw 'No table at $field';
      }

      // Remove the old table
      _lua.insert(-2);
      _lua.pop(1);
    }
  }

  void _getCreateTables(String variable, List<String> fields) {
    _lua.getGlobal(variable);

    for (final field in fields) {
      // Try getting the value
      _lua.getField(-1, field);

      // If its nil, set a new value and push it
      if (_lua.isNil(-1)) {
        _lua.pop(1);

        // Set the field to a new table
        _lua.newTable();
        _lua.setField(-2, field);

        // Get the new table
        _lua.getField(-1, field);
      }

      // Remove the old table
      _lua.insert(-2);
      _lua.pop(1);
    }
  }

  // Put the top object in the stack into the table (and removes it from the stack)
  void setTableEntry(String variable, List<String> fields) {
    _getCreateTables(variable, fields.sublist(0, fields.length - 1));

    // State should look like [value, table]
    _lua.insert(-2);
    _lua.setField(-2, fields.last);
    _lua.pop(1);
  }


  void pushUiComponent(int lensId, LuaUi component) {
    _lua.setTop(0);

    pushTableEntry(instancesVariable, ['$lensId', lensesUiField]);
    for (final index in component.path) {
      _lua.pushInteger(index + 1); // Lua is one indexed
      _lua.getTable(-2);
      // Remove the old table
      _lua.insert(-2);
      _lua.pop(1);
    }
  }

  void performPressAction(Map<String, dynamic> arguments) {
    _lua.getField(-1, 'press');
    push(arguments);
    contextCall(1, 0);
  }

  void performChangeAction(String content) {
    _lua.getField(-1, 'change');
    // Call the function with the string argument
    if (_lua.isFunction(-1)) {
      _lua.pushString(content);
      contextCall(1, 0);
    }
  }

  void performLensButtonAction(LensExtension lens, int actionIdx, int instanceId) {
    _lua.setTop(0);

    // Load the press function
    pushTableEntry(extsVariable, [...lens.lensFields, actionsField, actionIdx+1, 'press']);
    if (!_lua.isFunction(-1)) throw 'press is not a function';

    // Load the instance state
    pushTableEntry(instancesVariable, ['$instanceId', lensesStateField]);

    contextCall(1, 0);
  }


  static const luaRequireVariable = "*required*";

  int require(String packagePath, String module) {
    final modulePath = module.replaceAll('.', '/');

    _lua.getGlobal(luaRequireVariable);
    final requireTableIndex = _lua.getTop();

    for (final pathOption in packagePath.split(';')) {
      final relative = pathOption.replaceAll('?', modulePath);
      final file = File(resolvePath(relative));

      _lua.getField(requireTableIndex, file.path);
      if (!_lua.isNil(-1)) return 1;
      _lua.pop(1);

      if (file.existsSync()) {
        executeOrError(code: file.readAsStringSync());
        _lua.pushValue(-1);
        _lua.setField(requireTableIndex, file.path);
        return 1;
      }
    }

    throw 'Module $module does not exist';
  }


  int generateLensState(LensExtension lens, String content) {
    _lua.setTop(0);

    // Call the toState function on the content
    pushTableEntry(extsVariable, [...lens.lensFields, toStateField]);
    _lua.pushString(content);
    contextCall(1, 1);

    // Push the result into the instances table at index `randomId`
    final randomId = Random().nextInt(1000000000);
    setTableEntry(instancesVariable, [randomId.toString(), lensesStateField]);
    return randomId;
  }

  String generateLensText(LensExtension lens, int id) {
    _lua.setTop(0);

    // Call the text function on the state
    pushTableEntry(extsVariable, [...lens.lensFields, toTextField]);
    pushTableEntry(instancesVariable, [id.toString(), lensesStateField]);
    contextCall(1, 1);

    return _lua.toStr(-1)!;
  }

  LuaUi generateLensUi(LensExtension lens, int id) {
    _lua.setTop(0);

    // Call the ui function on the state
    pushTableEntry(extsVariable, [...lens.lensFields, toUiField]);
    pushTableEntry(instancesVariable, [id.toString(), lensesStateField]);
    contextCall(1, 1);

    // Copy the value reference, and put it into the instances table
    _lua.pushValue(-1);
    setTableEntry(instancesVariable, [id.toString(), lensesUiField]);

    return LuaUi.parseRoot(LuaObject.parse(_lua));
  }
}
