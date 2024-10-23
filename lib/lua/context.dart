import 'dart:math';

import 'package:lua_dardo/lua.dart';
import 'package:notes/editor/extensions.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/lua/functions.dart';
import 'package:notes/lua/object.dart';
import 'package:notes/lua/ui.dart';


// Lua variable used to store parsed tables to allow for circular references
const String tableCacheVariable = '*table-cache*';


class LuaContext {
  LuaContext.init(this.handler) : _lua = LuaState.newState() { _init(); }
  final LuaState _lua;
  final NoteHandler handler;


  // Calling arbitrary user code

  String? currentPwd;
  String? currentExtension;
  void _callUserFunction(int nargs, int nresults, {String? pwd, String? ext}) {
    final oldPwd = currentPwd;
    final oldExtension = currentExtension;

    currentPwd = pwd ?? currentPwd;
    currentExtension = ext ?? currentExtension;

    try {
      _lua.call(nargs, nresults);
    } finally {
      currentPwd = oldPwd;
      currentExtension = oldExtension;
    }
  }

  LuaObject executeUserCode(String code, {String? pwd}) {
    _lua.loadString(code);
    _callUserFunction(0, 1, pwd: pwd);
    return _parse();
  }

  void executeExtensionCode(String ext, String code) {
    try {
      _lua.loadString(code);
      _callUserFunction(0, 1);
      _setTableEntry(extsVariable, [ext, extsReturnField]);
    } catch (err) {
      print('Error loading $ext: $err');
    }
  }


  // Working with the stack

  LuaObject _parse({int index = -1, int? maxDepth, List<LuaTable>? tableCache}) {
    final nextMaxDepth = maxDepth == null ? null : maxDepth - 1;

    // Reset the table cache
    if (tableCache == null) {
      tableCache = [];
      _lua.newTable();
      _lua.setGlobal(tableCacheVariable);
    }

    if (_lua.isNil(index)) {
      return LuaNil();
    } else if (_lua.isInteger(index)) {
      return LuaNumber(_lua.toInteger(index));
    } else if (_lua.isNumber(index)) {
      return LuaNumber(_lua.toNumber(index));
    } else if (_lua.isBoolean(index)) {
      return LuaBoolean(_lua.toBoolean(index));
    } else if (_lua.isTable(index)) {
      if (maxDepth == 0) return LuaTable({});

      // Check if this is in the table cache
      _lua.pushValue(index);
      _lua.getGlobal(tableCacheVariable);
      _lua.insert(-2);
      _lua.getTable(-2);
      // Stack looks like [..., tableCache, index?]
      final cacheIndex = _lua.toIntegerX(-1);
      _lua.pop(2);
      if (cacheIndex != null) {
        return tableCache[cacheIndex];
      }

      // Add this table to the table cache
      _lua.pushValue(index);
      _lua.getGlobal(tableCacheVariable);
      _lua.insert(-2);
      _lua.pushInteger(tableCache.length);
      // Stack looks like [..., tableCache, table, index]
      _lua.setTable(-3);
      _lua.pop(1);

      final table = LuaTable({});
      tableCache.add(table);

      // When lua iterates through tables, it expects the stack to look like [table, ..., prevKey],
      // where table is at position index-1 (since it was at index before adding the key.)
      // Start with a nil key to indicate that the iteration hasn't started.
      _lua.pushNil();
      final indexNow = index < 0 ? index - 1 : index;
      while (_lua.next(indexNow)) {
        LuaObject value = _parse(maxDepth: nextMaxDepth, tableCache: tableCache);
        _lua.pop(1);  // Pop the value, keep the key for the next iteration
        LuaObject key = _parse(maxDepth: nextMaxDepth, tableCache: tableCache);
        table.value[key] = value;
      }

      return table;
    } else if (_lua.isString(index)) {
      return LuaString(_lua.toStr(index)!);
    } else {
      return LuaOther(_lua.type(index));
    }
  }

  void _push(LuaObject obj) {
    switch (obj) {
      case LuaNil(): return _lua.pushNil();
      case LuaString(): return _lua.pushString(obj.value);
      case LuaNumber(): {
        final n = obj.value;
        if (n is int) {
          _lua.pushInteger(n);
        } else {
          _lua.pushNumber(n.toDouble());
        }
        return;
      }
      case LuaBoolean(): return _lua.pushBoolean(obj.value);
      case LuaTable(): {
        _lua.newTable();
        for (final entry in obj.value.entries) {
          _push(entry.key);
          _push(entry.value);
          _lua.setTable(-3);
        }
        return;
      }
      case LuaOther(): _lua.pushNil();
    }
  }

  // For debugging purposes
  void printStack() => print(_parseStack());
  List<LuaObject> _parseStack() {
    final h = _lua.getTop();
    return List.generate(h, (idx) => _parse(index: idx - h));
  }


  // File system

  String resolvePath(String relative) => concatPaths(currentPwd ?? '/', relative);

  String resolveExistsOrErr(String relative, {FileType type = FileType.file, bool create = false}) {
    final path = resolvePath(relative);
    final actualType = handler.fs.exists(path);

    if (actualType == null && create) {
      handler.fs.createOrErr(path, ft: type);
    } else if (actualType == null) {
      throw '$relative does not exist';
    } else if (actualType != type) {
      throw '$relative is a $actualType';
    }
    return path;
  }


  // Table Utils

  void _pushTableEntry(String variable, List<dynamic> fields) {
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
  void _setTableEntry(String variable, List<String> fields) {
    _getCreateTables(variable, fields.sublist(0, fields.length - 1));

    // State should look like [value, table]
    _lua.insert(-2);
    _lua.setField(-2, fields.last);
    _lua.pop(1);
  }


  // Ui functions

  // Grab a lui component from the cache of active lens instances
  void pushLuiComponent(int lensId, LuiComponent comp) {
    _lua.setTop(0);

    _pushTableEntry(instancesVariable, ['$lensId', lensesUiField]);
    for (final index in comp.path) {
      _lua.pushInteger(index + 1); // Lua is one indexed
      _lua.getTable(-2);
      // Remove the old table
      _lua.insert(-2);
      _lua.pop(1);
    }
  }

  void performPressAction(Map<String, dynamic> actionArgs) {
    _lua.getField(-1, 'press');
    _push(LuaObject.fromJson(actionArgs));
    _callUserFunction(1, 0);
  }

  void performChangeAction(String content) {
    _lua.getField(-1, 'change');
    // Call the function with the string argument
    if (_lua.isFunction(-1)) {
      _lua.pushString(content);
      _callUserFunction(1, 0);
    }
  }


  // Generating lenses

  void defineLens(LensExtension lens) => _setTableEntry(extsVariable, lens.lensFields);

  int initializeLensInstance(LensExtension lens, String content) {
    _lua.setTop(0);

    // Call the toState function on the content
    _pushTableEntry(extsVariable, [...lens.lensFields, toStateField]);
    _lua.pushString(content);
    _callUserFunction(1, 1);

    // Push the result into the instances table at index `randomId`
    final randomId = Random().nextInt(1000000000);
    _setTableEntry(instancesVariable, [randomId.toString(), lensesStateField]);
    return randomId;
  }

  String generateLensText(LensExtension lens, int id) {
    _lua.setTop(0);

    // Call the text function on the state
    _pushTableEntry(extsVariable, [...lens.lensFields, toTextField]);
    _pushTableEntry(instancesVariable, [id.toString(), lensesStateField]);
    _callUserFunction(1, 1);

    return _lua.toStr(-1)!;
  }

  LuiComponent generateLensUi(LensExtension lens, int id) {
    _lua.setTop(0);

    // Call the ui function on the state
    _pushTableEntry(extsVariable, [...lens.lensFields, toUiField]);
    _pushTableEntry(instancesVariable, [id.toString(), lensesStateField]);
    _callUserFunction(1, 1);

    // Copy the value reference, and put it into the instances table
    _lua.pushValue(-1);
    _setTableEntry(instancesVariable, [id.toString(), lensesUiField]);

    return LuiComponent.parse(_parse());
  }

  void disposeLensInstance(int id) {
    _lua.pushNil();
    _setTableEntry(extsVariable, [id.toString()]);
  }


  // Initialization

  static const requiredModulesVariable = "*required*";

  int require(String packagePath, String module) {
    final modulePath = module.replaceAll('.', '/');

    _lua.getGlobal(requiredModulesVariable);
    final requireTableIndex = _lua.getTop();

    for (final pathOption in packagePath.split(';')) {
      final path = resolvePath(pathOption.replaceAll('?', modulePath));
      _lua.getField(requireTableIndex, path);
      if (!_lua.isNil(-1)) return 1;
      _lua.pop(1);

      if (handler.fs.existsFile(path)) {
        _lua.loadString(handler.fs.readOrErr(path));
        _callUserFunction(0, 1, pwd: path);
        _lua.pushValue(-1);
        _lua.setField(requireTableIndex, path);
        return 1;
      }
    }

    throw 'Module $module does not exist';
  }

  void _registerFunctions(String varName) {
    // Table to hold all of the dart functions
    _lua.newTable();

    // Add raw functions to the table
    for (final pushFn in pushFunctions.entries) {
      _lua.pushDartFunction((_) => pushFn.value(this, _parseStack()));
      _lua.setField(-2, pushFn.key);
    }

    // Add returning functions to the table
    for (final returnFn in returnFunctions.entries) {
      _lua.pushDartFunction((LuaState _) {
          _push(returnFn.value(this, _parseStack()));
          return 1;
      });
      _lua.setField(-2, returnFn.key);
    }

    // Store the table in the specified name
    _lua.setGlobal(varName);
  }

  void _stripLibFunctions(String lib, {required List<String> keep}) {
    _lua.getGlobal(lib);
    if (!_lua.isTable(-1)) {
      _lua.pop(1);
      return;
    }

    _lua.pushNil();
    while (_lua.next(-2)) {
      _lua.pop(1); // Pop the value
      if (!keep.contains(_lua.toStr(-1))) {
        _lua.pushValue(-1);
        _lua.pushNil();
        // Stack is [lib, key, key, nil]
        _lua.setTable(-4);
      }
    }
    _lua.pop(1);
  }

  void _init() {
    // Load lua libraries
    _lua.openLibs();

    // Remove access to the filesystem
    _lua.doString('loadfile = nil');
    _stripLibFunctions('os', keep: ['clock', 'difftime', 'date', 'time']);
    // The io library doesn't get created by luadardo
    _lua.doString('io = {stdout=print}');

    // Register dart functions
    const funcVar = 'App';
    _registerFunctions(funcVar);
    _lua.doString('require = $funcVar.require');

    // Initialize global tables
    for (final variable in [extsVariable, instancesVariable, requiredModulesVariable]) {
      _lua.newTable();
      _lua.setGlobal(variable);
    }
  }
}
