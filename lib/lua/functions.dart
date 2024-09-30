import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


// Functions which manually push their output onto the stack, and return the number of outputs
final pushFunctions = <String, int Function(LuaContext)> {
  'import': (lua) {
    ensureArgCount(lua, 1);
    final extName = ensureLuaString(lua.object(1), 'extension');

    // Push the scope onto the stack
    lua.pushTableEntry(extsVariable, [extName, extsReturnField]);
    return 1;
  },

  'load_file': (lua) {
    ensureArgCount(lua, 1);
    final relative = ensureLuaString(lua.object(1), 'file');
    final file = lua.resolveExistingFile(relative);

    final sp = StructureParser.fromFile(file.path) ?? (throw 'Invalid load file');
    final code = sp.parse(file.readAsStringSync()).getLuaCode();
    lua.inDir(file.parent).executeOrError(code: code);
    return 1;
  },
  'require': (lua) {
    ensureArgCount(lua, 1);
    final module = ensureLuaString(lua.object(1), 'module');

    lua.pushTableEntry('package', ['path']);
    final packagePath = ensureLuaString(lua.object(-1), 'package.path');

    return lua.require(packagePath, module);
  },
};

// Functions which return their output
final returnFunctions = <String, dynamic Function(LuaContext)>{
  'resolve_file': (lua) {
    ensureArgCount(lua, 1);
    final file = lua.resolveExistingFile(ensureLuaString(lua.object(1), 'file'));
    return file.absolute.path;
  },
  'resolve_directory': (lua) {
    ensureArgCount(lua, 1);
    final file = lua.resolveExistingFile(ensureLuaString(lua.object(1), 'file'));
    return file.absolute.path;
  },

  'print_stack': (lua) {
    // ignore: avoid_print
    print('STACK: ${lua.stack()}');
  },

  'parse_markdown': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(lua.object(1), 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_markdown': (lua) {
    ensureArgCount(lua, 1);
    final structure = ensureLuaTable(lua.object(1), 'structure');
    return const MarkdownStructureMarkup().format(Structure.fromLua(structure));
  },
  'parse_org': (lua) {
    ensureArgCount(lua, 1);
    final content = ensureLuaString(lua.object(1), 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_org': (lua) {
    ensureArgCount(lua, 1);
    final structure = ensureLuaTable(lua.object(1), 'structure');
    return const OrgStructureMarkup().format(Structure.fromLua(structure));
  },

  'deflens': (lua) {
    final extDir = lua.ext;
    if (extDir == null) throw 'Can only define a lens inside an extension';

    ensureArgCount(lua, 1);
    final table = ensureLuaTable(lua.object(1), 'lens');
    final name = ensureLuaString(table['name'] ?? LuaNil(), 'lens.name');

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field] ?? LuaNil(), LuaType.luaFunction, 'lens.$field');
    }

    // Get the actions
    final actionsTable = ensureLuaTable(table[actionsField] ?? LuaTable({}), 'lens.actions');
    final actions = actionsTable.listValues.indexed.map((indexed) {
        final (idx, actionObj) = indexed;
        final actionTbl = ensureLuaTable(actionObj, 'lens.$actionsField[${idx+1}]');
        final iconName = ensureLuaString(actionTbl['icon'] ?? LuaNil(), 'lens.$actionsField[${idx+1}].icon');
        final icon = MdiIcons.fromString(iconName) ?? Icons.question_mark;
        ensureLuaType(actionTbl['press'] ?? LuaNil(), LuaType.luaFunction, 'lens.$actionsField[${idx+1}].press');
        return iconAction<GlobalKey>(icon, (ps) => LensStateWidgetState.buttonAction(ps, idx));
    }).toList();

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name, actions: actions);
    lensTypes.add(lens);

    // Add it to the lua table
    lua.setTableEntry(extsVariable, lens.lensFields);
  },

  'read_file': (lua) {
    ensureArgCount(lua, 1);
    final file = lua.resolveExistingFile(ensureLuaString(lua.object(1), 'file'));
    return file.readAsStringSync();
  },
  'parse_file': (lua) {
    ensureArgCount(lua, 1);
    final file = lua.resolveExistingFile(ensureLuaString(lua.object(1), 'file'));
    final sp = StructureParser.fromFile(file.path) ?? (throw 'Invalid parse file type');
    return sp.parse(file.readAsStringSync());
  },
  'parse_directory': (lua) {
    ensureArgCount(lua, 1);
    final relative = ensureLuaString(lua.object(1), 'directory');

    // Get a list of structures
    final dir = lua.resolveExistingDir(relative);
    final structs = dir.listSync().whereType<File>().map((f) {
        final sp = StructureParser.fromFile(f.path);
        return sp == null ? null : (f, sp.parse(f.readAsStringSync()));
    }).whereType<(File, Structure)>();

    lua.push(structs.map((tup) => tup.$2).toList());
    return 1;
  },
  'list_files': (lua) {
    ensureArgCount(lua, 1);
    final dir = lua.resolveExistingDir(ensureLuaString(lua.object(1), 'directory'));
    return dir.listSync().map((f) => f.path).toList();
  },

  'open': (lua) {
    ensureArgCount(lua, 1, max: 2);
    final relative = ensureLuaString(lua.object(1), 'file');
    final create = lua.object(2).isTruthy;
    final file = lua.resolveExistingFile(relative, create: create);
    lua.handler.openFile(file);
  },
};
