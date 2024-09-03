import 'dart:io';

import 'package:lua_dardo/lua.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/main.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


String _resolvePath(String relative) {
  final path = (
    relative.startsWith('~/')
    ? repoRootDirectory.uri.resolve(relative.substring(2)).path
    : File(relative).isAbsolute
    ? relative
    : (luaCurrentFile?.parent ?? repoRootDirectory).uri.resolve(relative).path
  );

  if (!path.startsWith(repoRootDirectory.path)) {
    throw 'File $relative is outside of the repo';
  }
  return path;
}

File _resolveFile(String relative) {
  final file = File(_resolvePath(relative));
  if (!file.existsSync()) throw 'File $relative does not exist';
  return file;
}

Directory _resolveDir(String relative) {
  final dir = Directory(_resolvePath(relative));
  if (!dir.existsSync()) throw 'Directory $relative does not exist';
  return dir;
}



// Functions which manually push their output onto the stack, and return the number of outputs
final pushFunctions = <String, int Function(LuaState)> {
  // Outdated
  'import': (lua) {
    ensureArgCount(lua, 1);
    final extName = ensureLuaString(LuaObject.parse(lua, index: 1), 'extension');

    // Push the scope onto the stack
    luaPushTableEntry(lua, extsVariable, [extName, extsScopeField]);
    return 1;
  },

  'load_file': (lua) {
    ensureArgCount(lua, 1, max: 2);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    final noFile = LuaObject.parse(lua, index: 2).isTruthy;

    // Check the file type
    final sp = StructureParser.fromFile(file.path) ?? (
      file.path.endsWith('.lua') ? null : throw 'Invalid load file'
    );

    // Parse the code from the file
    final contents = file.readAsStringSync();
    final code = sp == null ? contents : sp.parse(contents).getLuaCode();

    luaExecuteFileOrError(lua, code, noFile ? null : file);
    return 1;
  },

  'parse_directory': (lua) {
    ensureArgCount(lua, 1, max: 3);
    final relativeDir = ensureLuaString(LuaObject.parse(lua, index: 1), 'directory');
    final modifier = ensureLuaTypeOrNone(LuaObject.parse(lua, index: 2), LuaType.luaFunction, 'modifier');
    final err = ensureLuaTypeOrNone<LuaBoolean>(LuaObject.parse(lua, index: 3), LuaType.luaBoolean, 'err');

    // Get a list of structures
    final dir = _resolveDir(relativeDir);
    final structs = dir.listSync().whereType<File>().map((f) {
        final sp = StructureParser.fromFile(f.path);
        return sp == null ? null : (f, sp.parse(f.readAsStringSync()));
    }).whereType<(File, Structure)>();

    // If there is no function, return the list of structs
    if (modifier == null) {
      toLua(structs.map((tup) => tup.$2).toList()).put(lua);
      return 1;
    }

    // Create a table for the structs, and then push the function results into the table
    lua.newTable();
    for (final (file, struct) in structs) {
      // Call the function with the struct as the argument
      lua.pushValue(2);
      toLua(struct).put(lua);
      final status = lua.pCall(1, 1, 0);

      // The stack looks like [dir, function, table, result/error]
      if (status == ThreadStatus.luaOk) {
        // Add the result to the table
        lua.pushString(fileName(file));
        lua.insert(-2);
        lua.setTable(-3);
      } else if (err == LuaBoolean(true)) {
        // Throw the error if the user specified not to ignore errors
        throw lua.toStr(-1)!;
      } else {
        // Pop the error message
        lua.pop(1);
      }
    }

    return 1;
  },
};

// Functions which return their output
final returnFunctions = <String, dynamic Function(LuaState)>{
  'resolve_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    return file.absolute.path;
  },
  'resolve_directory': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveDir(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    return file.absolute.path;
  },

  'print_stack': (lua) {
    // ignore: avoid_print
    print('STACK: ${parseStack(lua)}');
  },

  'parse_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua, index: 1), 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_markdown': (lua) {
    ensureArgCount(lua, 1);
    final structure = ensureLuaTable(LuaObject.parse(lua, index: 1), 'structure');
    return const MarkdownStructureMarkup().format(Structure.fromLua(structure));
  },
  'parse_org': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(LuaObject.parse(lua, index: 1), 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_org': (lua) {
    ensureArgCount(lua, 1);
    final structure = ensureLuaTable(LuaObject.parse(lua, index: 1), 'structure');
    return const OrgStructureMarkup().format(Structure.fromLua(structure));
  },

  'deflens': (lua) {
    final extDir = loadingExtension;
    if (extDir == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 1);
    final table = ensureLuaTable(LuaObject.parse(lua, index: 1), 'functions');
    final name = ensureLuaString(table['name'] ?? LuaNil(), 'name');

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field] ?? LuaNil(), LuaType.luaFunction, 'functions.$field');
    }

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name);
    lensTypes.add(lens);

    // Add it to the lua table
    luaSetTableEntry(lua, extsVariable, lens.lensFields);
  },

  'read_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    return file.readAsStringSync();
  },
  'parse_file': (lua) {
    ensureArgCount(lua, 1);
    final file = _resolveFile(ensureLuaString(LuaObject.parse(lua, index: 1), 'file'));
    final sp = StructureParser.fromFile(file.path) ?? (throw 'Invalid parse file type');
    return sp.parse(file.readAsStringSync());
  },
  'list_files': (lua) {
    ensureArgCount(lua, 1);
    final dir = _resolveDir(ensureLuaString(LuaObject.parse(lua, index: 1), 'directory'));
    return dir.listSync().map((f) => f.path).toList();
  },
};

void registerLuaFunctions(LuaState lua, String tableName) {
  // Table to hold all of the dart functions
  lua.newTable();

  // Add raw functions to the table
  for (final pushFn in pushFunctions.entries) {
    lua.pushDartFunction(pushFn.value);
    lua.setField(-2, pushFn.key);
  }

  // Add returning functions to the table
  for (final returnFn in returnFunctions.entries) {
    lua.pushDartFunction((LuaState lua) {
        final output = returnFn.value(lua);
        toLua(output).put(lua);
        return 1;
    });
    lua.setField(-2, returnFn.key);
  }

  // Store the table in the specified name
  lua.setGlobal(tableName);
}
