import 'package:lua_dardo/lua.dart';
import 'package:notes/editor/extensions.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/lua/ensure.dart';
import 'package:notes/lua/object.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_parser.dart';

final pushFunctions = <String, int Function(LuaContext lua, List<LuaObject> args)>{
  'load_file': (lua, args) {
    ensureArgCount(args.length, 1);
    final file = lua.resolveExistsOrErr(ensureLuaString(args[0], 'file'));

    final sp = StructureParser.fromFile(file) ?? (throw 'Invalid load file');
    final code = sp.parse(lua.handler.fs.readOrErr(file)).getLuaCode();
    lua.executeUserCode(code, pwd: fileParent(file));
    return 1;
  },
  'require': (lua, args) {
    ensureArgCount(args.length, 1);
    final module = ensureLuaString(args[0], 'module');
    final packagePath = ensureLuaString(lua.executeUserCode('return package.path'), 'package.path');
    return lua.require(packagePath, module);
  },
};

final returnFunctions = <String, dynamic Function(LuaContext, List<LuaObject> args)>{
  'resolve_file': (lua, args) {
    ensureArgCount(args.length, 1);
    return lua.resolveExistsOrErr(ensureLuaString(args[0], 'path'));
  },
  'resolve_directory': (lua, args) {
    ensureArgCount(args.length, 1);
    return lua.resolveExistsOrErr(ensureLuaString(args[0], 'path'), type: FileType.directory);
  },

  'parse_markdown': (lua, args) {
    ensureArgCount(args.length, 1);
    final content = ensureLuaString(args[0], 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_markdown': (lua, args) {
    ensureArgCount(args.length, 1);
    final structure = ensureLuaTable(args[0], 'structure');
    return const MarkdownStructureMarkup().format(Structure.parseFromLua(structure));
  },
  'parse_org': (lua, args) {
    ensureArgCount(args.length, 1);
    final content = ensureLuaString(args[0], 'string');
    return const MarkdownStructureMarkup().parse(content);
  },
  'to_org': (lua, args) {
    ensureArgCount(args.length, 1);
    final structure = ensureLuaTable(args[0], 'structure');
    return const OrgStructureMarkup().format(Structure.parseFromLua(structure));
  },

  'defwidget': (lua, args) {
    final extDir = lua.currentExtension;
    if (extDir == null) throw 'Can only define a widget inside an extension';

    ensureArgCount(args.length, 1);
    final table = ensureLuaTable(args[0], 'lens');
    final name = ensureLuaString(table['name'] ?? LuaNil(), 'lens.name');

    // Check the function fields
    for (final field in [toStateField, toTextField, toUiField]) {
      ensureLuaType(table[field] ?? LuaNil(), LuaType.luaFunction, 'lens.$field');
    }

    // Get the actions
    // final actionsTable = ensureLuaTable(table[actionsField] ?? LuaTable({}), 'lens.actions');
    // final actions = actionsTable.listValues.indexed.map((indexed) {
    //     final (idx, actionObj) = indexed;
    //     final actionTbl = ensureLuaTable(actionObj, 'lens.$actionsField[${idx+1}]');
    //     final iconName = ensureLuaString(actionTbl['icon'] ?? LuaNil(), 'lens.$actionsField[${idx+1}].icon');
    //     final icon = MdiIcons.fromString(iconName) ?? Icons.question_mark;
    //     ensureLuaType(actionTbl['press'] ?? LuaNil(), LuaType.luaFunction, 'lens.$actionsField[${idx+1}].press');
    //     return iconAction<GlobalKey>(icon, (ps) => LensStateWidgetState.buttonAction(ps, idx));
    // }).toList();

    // Get the name
    final lens = LensExtension(ext: fileName(extDir), name: name);
    lensTypes.add(lens);

    // Store it in the lenses table within lua
    lua.defineLens(lens);
  },

  'read_file': (lua, args) {
    ensureArgCount(args.length, 1);
    final file = lua.resolveExistsOrErr(ensureLuaString(args[0], 'file'));
    return lua.handler.fs.readOrErr(file);
  },
  'parse_file': (lua, args) {
    ensureArgCount(args.length, 1);
    final file = lua.resolveExistsOrErr(ensureLuaString(args[0], 'file'));
    final sp = StructureParser.fromFile(file) ?? (throw 'Invalid parse file type');
    return sp.parse(lua.handler.fs.readOrErr(file));
  },
  'parse_directory': (lua, args) {
    ensureArgCount(args.length, 1);
    final relative = ensureLuaString(args[0], 'directory');

    // Get a list of structures
    final dir = lua.resolveExistsOrErr(relative, type: FileType.directory);
    final entries = lua.handler.fs.listFilesOrErr(dir).expand((f) {
        final sp = StructureParser.fromFile(f);
        return sp == null ? <MapEntry>[] : [MapEntry(f, sp.parse(lua.handler.fs.readOrErr(f)))];
    });
    return Map.fromEntries(entries);
  },
  'list_files': (lua, args) {
    ensureArgCount(args.length, 1);
    final dir = lua.resolveExistsOrErr(ensureLuaString(args[0], 'directory'), type: FileType.directory);
    return lua.handler.fs.listFilesOrErr(dir);
  },

  'open': (lua, args) {
    ensureArgCount(args.length, 1, max: 2);
    final relative = ensureLuaString(args[0], 'file');
    final create = args.elementAtOrNull(1)?.isTruthy == true;
    final file = lua.resolveExistsOrErr(relative, create: create);
    lua.handler.openFile(file);
  },
};
