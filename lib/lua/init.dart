import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/lua/functions.dart';


const String exportsField = '*exports*';
const String scopeField = '*scope*';


void _createGlobalTable(LuaState ls, String variable) {
  ls.newTable();
  ls.setGlobal(variable);
}

void _stripLibFunctions(LuaState ls, String lib, {required List<String> keep}) {
  ls.getGlobal(lib);
  if (!ls.isTable(-1)) {
    ls.pop(1);
    return;
  }

  ls.pushNil();
  while (ls.next(-2)) {
    ls.pop(1); // Pop the value
    if (!keep.contains(ls.toStr(-1))) {
      ls.pushValue(-1);
      ls.pushNil();
      // Stack is [lib, key, key, nil]
      ls.setTable(-4);
    }
  }
  ls.pop(1);
}

void _registerLuaFunctions(LuaState ls, String varName) {
  // Table to hold all of the dart functions
  ls.newTable();

  // Add raw functions to the table
  for (final pushFn in pushFunctions.entries) {
    ls.pushDartFunction((_) => pushFn.value(LuaContext.current!));
    ls.setField(-2, pushFn.key);
  }

  // Add returning functions to the table
  for (final returnFn in returnFunctions.entries) {
    ls.pushDartFunction((LuaState _) {
        final lua = LuaContext.current!;
        lua.push(returnFn.value(lua));
        return 1;
    });
    ls.setField(-2, returnFn.key);
  }

  // Store the table in the specified name
  ls.setGlobal(varName);
}


LuaState createLuaState() {
  final ls = LuaState.newState();

  // Load lua libraries
  ls.openLibs();

  // Remove access to the filesystem
  ls.doString('loadfile = nil');
  _stripLibFunctions(ls, 'os', keep: ['clock', 'difftime', 'date', 'time']);
  // The io library doesn't get created by luadardo
  ls.doString('io = {stdout=print}');
  _stripLibFunctions(ls, 'io', keep: ['stdout']);

  // Register dart functions
  _registerLuaFunctions(ls, 'App');

  // Initialize global tables
  _createGlobalTable(ls, extsVariable);
  _createGlobalTable(ls, instancesVariable);
  _createGlobalTable(ls, LuaContext.luaRequireVariable);

  return ls;
}
