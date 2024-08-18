import 'dart:io';
import 'dart:math';

import 'package:notes/extensions/lua.dart';
import 'package:notes/extensions/lua_object.dart';
import 'package:notes/extensions/lua_ui.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/parse_structure.dart';
import 'package:notes/structure/structure.dart';


List<LensExtension> lensExtensions = [];

const String lensDirectory = 'lenses';
const String lensFileExtension = '.md';
const String lensesVariable = '__lenses__';
const String instancesVariable = '__lens_instances__';

const String toStateHeading = 'Parse';
const String toTextHeading = 'Print';
const String toUiHeading = 'Render';


class LensExtension {
  LensExtension({required this.dir, required this.name});
  final String dir;
  final String name;

  void _loadFunction(String heading) {
    luaState.getGlobal(lensesVariable);

    luaState.pushString(dir);
    luaState.getTable(-2);

    luaState.pushString(name);
    luaState.getTable(-2);

    luaState.pushString(heading.toLowerCase());
    luaState.getTable(-2);

    // Stack is [lenses, dir, lens, function]
    luaState.insert(-4);
    luaState.pop(3);
  }

  int generateState(String content) {
    luaState.setTop(0);

    final randomId = Random().nextInt(1000000000);
    luaState.getGlobal(instancesVariable);
    luaState.pushString('$randomId');

    // Call the function
    _loadFunction(toStateHeading);
    luaState.pushString(content);
    luaState.call(1, 1);

    // Push the result into the instances table at index `randomId`
    luaState.setTable(-3);

    return randomId;
  }

  String generateText(int id) {
    luaState.setTop(0);

    // Get the current state
    luaState.getGlobal(instancesVariable);
    _loadFunction(toTextHeading);
    luaState.pushString('$id');
    // Stack is [instances, toTextFn, id]
    luaState.getTable(-3);
    // Stack is [instances, toTextFn, instance]
    luaState.call(1, 1);

    return luaState.toStr(-1)!;
  }

  LuaUi generateUi(int id) {
    luaState.setTop(0);

    // Get the current state
    luaState.getGlobal(instancesVariable);
    _loadFunction(toUiHeading);
    luaState.pushString('$id');
    // Stack is [instances, toUiFn, id]
    luaState.getTable(-3);
    // Stack is [instances, toUiFn, instance]
    luaState.call(1, 1);

    return LuaUi.parse(LuaObject.parse(luaState));
  }
}


// Evaluate the lens functions in lua, and store them in `lensesVariable.dir.name`
void _initializeLens(String dir, String name, NoteStructure struct) {
  // Load a new table into the stack
  luaState.loadString('return {}');
  luaState.call(0, 1);

  // Load the 3 properties for the table
  for (final heading in [toStateHeading, toTextHeading, toUiHeading]) {
    // Get the heading
    final headBody = struct.getHeading(heading, noCase: true);
    if (headBody == null) throw 'Missing heading $heading';

    // Exctract the code
    final code = headBody.content.expand<String>((elem) => (
        (elem is StructureCode && elem.language == 'lua') ? [elem.content, '\n'] : []
    )).join();
    if (code.isEmpty) throw 'No code block in heading $heading';

    // Load the arguments
    luaState.pushString(heading.toLowerCase());
    luaState.loadString(code);
    luaState.call(0, 1);
    if (!luaState.isFunction(-1)) throw 'Heading $heading did not return function';

    luaState.setTable(-3);
  }

  luaState.getGlobal(lensesVariable);

  // Create the table if it doesn't exist
  final dirAccess = '$lensesVariable["$dir"]';
  luaState.doString('if $dirAccess == nil then $dirAccess = {} end');

  // Push the table to the stack
  luaState.pushString(dir);
  luaState.getTable(-2);

  // Now the stack is [lens, global, dir]
  luaState.insert(-3);
  luaState.pop(1);
  // Now the stack is [dir, lens]
  luaState.pushString(name);
  luaState.insert(-2);
  // Now the stack is [dir, filename, lens]
  luaState.setTable(-3);

  luaState.setTop(0);
}

Future<void> loadLenses(Directory rootDir) async {
  final lensDir = Directory.fromUri(rootDir.uri.resolve(lensDirectory));
  final subDirs = (await lensDir.list().toList()).whereType<Directory>();

  final lensFiles = (await Future.wait(
      subDirs.map((subDir) async => (
          (await subDir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith(lensFileExtension))
          .toList()
      ))
  )).expand((x) => x);

  // Parse the files
  final lensBodies = await Future.wait(
    lensFiles.map((file) async {
        final fileName = file.uri.pathSegments.last;
        final fileNameBase = fileName.substring(0, fileName.length - lensFileExtension.length);
        final dirName = file.uri.pathSegments[file.uri.pathSegments.length - 2];
        final fileBody = await file.readAsString();
        return (name: fileNameBase, dir: dirName, body: fileBody);
    })
  );

  final lensFutures = lensBodies.map((file) async {
      try {
        final struct = parseStructure(file.body.split('\n'));
        _initializeLens(file.dir, file.name, struct);
        return [LensExtension(dir: file.dir, name: file.name)];

      } catch (e) {
        print('Error parsing ${file.dir}/${file.name}: $e');
        return <LensExtension>[];

      } finally {
        luaState.setTop(0);
      }
  });

  lensExtensions = (await Future.wait(lensFutures)).expand((x) => x).toList();
}


LensExtension? getLens(String dir, String name) => (
  lensExtensions
  .where((lens) => lens.name == name && lens.dir == dir)
  .firstOrNull
);
