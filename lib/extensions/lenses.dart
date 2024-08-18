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

const String toStateHeading = 'Parse';
const String toTextHeading = 'Print';
const String toUiHeading = 'Render';

const String lensesVariable = '__lenses__';
const String instancesVariable = '__lens_instances__';
const String instanceStateField = 'state';
const String instanceUiField = 'ui';


class LensExtension {
  LensExtension({required this.dir, required this.name});
  final String dir;
  final String name;

  int generateState(String content) {
    luaState.setTop(0);

    // Call the toState function on the content
    luaLoadTableEntry(lensesVariable, [dir, name, toStateHeading.toLowerCase()]);
    luaState.pushString(content);
    luaState.call(1, 1);

    // Push the result into the instances table at index `randomId`
    final randomId = Random().nextInt(1000000000);
    luaSetTableEntry(instancesVariable, [randomId.toString(), instanceStateField]);
    return randomId;
  }

  String generateText(int id) {
    luaState.setTop(0);

    // Call the text function on the state
    luaLoadTableEntry(lensesVariable, [dir, name, toTextHeading.toLowerCase()]);
    luaLoadTableEntry(instancesVariable, [id.toString(), instanceStateField]);
    luaState.call(1, 1);

    return luaState.toStr(-1)!;
  }

  LuaUi generateUi(int id) {
    luaState.setTop(0);

    // Call the ui function on the state
    luaLoadTableEntry(lensesVariable, [dir, name, toUiHeading.toLowerCase()]);
    luaLoadTableEntry(instancesVariable, [id.toString(), instanceStateField]);
    luaState.call(1, 1);

    // Copy the value reference, and put it into the instances table
    luaState.pushValue(-1);
    luaSetTableEntry(instancesVariable, [id.toString(), instanceUiField]);

    return LuaUi.parse(LuaObject.parse(luaState));
  }
}


// Evaluate the lens functions in lua, and store them in `lensesVariable.dir.name`
void _initializeLensHeading(String dir, String name, String heading, NoteStructure struct) {
  // Get the heading
  final headBody = struct.getHeading(heading, noCase: true);
  if (headBody == null) throw 'Missing heading $heading';

  // Exctract the code
  final code = headBody.content.expand<String>((elem) => (
      (elem is StructureCode && elem.language == 'lua') ? [elem.content, '\n'] : []
  )).join();
  if (code.isEmpty) throw 'No code block in heading $heading';

  // Generate the function onto the stack
  luaState.loadString(code);
  luaState.call(0, 1);
  if (!luaState.isFunction(-1)) throw 'Heading $heading did not return function';

  luaSetTableEntry(lensesVariable, [dir, name, heading.toLowerCase()]);
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
        // Load the 3 properties for the table
        for (final heading in [toStateHeading, toTextHeading, toUiHeading]) {
          _initializeLensHeading(file.dir, file.name, heading, struct);
        }
        return [LensExtension(dir: file.dir, name: file.name)];

      } catch (e) {
        // ignore: avoid_print
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
