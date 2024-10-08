import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/drawer/file_browser.dart';
import 'package:notes/drawer/git_manager.dart';
import 'package:notes/drawer/left_drawer.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/repo_manager.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/structure/structure_type.dart';


class NoteHandler extends StatefulWidget {
  const NoteHandler({super.key});

  @override
  // ignore: no_logic_in_create_state
  State<NoteHandler> createState() => NoteHandlerState(
    repoRoot: Directory('/home/benzanol/Documents/repo'),
  );
}

class NoteHandlerState extends State<NoteHandler> {
  NoteHandlerState({required this.repoRoot});
  final Directory repoRoot;
  late final repo = RepoManager(directory: repoRoot);

  bool _loadedExtensions = false;
  bool raw = false;
  late File note = repo.repoFile(
    ['index.md', 'index.org']
    .where((f) => repo.repoFile(f).existsSync())
    .firstOrNull
    ?? (() {
        repo.repoFile('index.md').createSync();
        return 'index.md';
    })()
  );

  late final gitManager = GitStatus(handler: this);
  late final fileBrowserState = FileBrowserState(root: repoRoot, open: [], git: gitManager);

  void markNoteModified(NoteEditor editor) => repo.markModified(editor.widget.file, editor);

  void openFile(File file) => setState(() => note = file);

  @override
  Widget build(BuildContext context) {
    if (!_loadedExtensions) {
      // Start initialize lenses
      final lua = LuaContext.global(this, context);
      loadExtensions(lua, repoRoot).then((_) => setState(() => _loadedExtensions = true));
      return const Text('Loading');
    }

    return FutureBuilder(
      future: repo.getContents(note),
      builder: (context, snapshot) {
        final data = snapshot.data;

        final indexFileRefreshButton = (
          (isExtensionIndexFile(repoRoot, note) && data != null)
          ? IconBtn(
            padding: 8,
            icon: Icons.refresh,
            onPressed: () {
              final lua = LuaContext.global(this, context);
              final struct = StructureParser.fromFileOrDefault(note.path).parse(data);
              runExtensionCode(lua, note, struct);
            },
          )
          : Container()
        );

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(
              child: Text(note.path.replaceFirst('${repoRoot.path}/', ''))
            ),
            actions: [
              Row(children: [
                  indexFileRefreshButton,
                  const Text('Raw'),
                  Switch(value: raw, onChanged: (b) => setState(() { raw = b; })),
              ]),
            ],
          ),
          drawer: LeftDrawer(child:
              FileBrowser(
                state: fileBrowserState,
                openFile: (file) {
                  // Close the drawer
                  Navigator.pop(context);
                  setState(() => note = file);
                },
              ),
          ),
          body: (
            (snapshot.connectionState != ConnectionState.done) ? const Text('LOADING')
            : (data == null) ? const Text('Null data')
            : NoteEditorWidget(handler: this, file: note, init: data, isRaw: raw)
          ),
        );
      },
    );
  }
}
