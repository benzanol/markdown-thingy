import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/drawer/left_drawer.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/state.dart';
import 'package:notes/extensions/load_extensions.dart';
import 'package:notes/lua/lua_state.dart';
import 'package:notes/main.dart';
import 'package:notes/structure/structure_type.dart';


class NoteHandler extends StatefulWidget {
  NoteHandler({super.key, required this.directory})
  : state = NotesState(directory: directory);
  final Directory directory;
  final NotesState state;

  @override
  State<NoteHandler> createState() => _NoteHandlerState();
}

class _NoteHandlerState extends State<NoteHandler> {
  _NoteHandlerState();

  bool ready = false;
  bool raw = false;
  late File note = widget.state.repoFile(
    ['index.md', 'index.org']
    .where((f) => widget.state.repoFile(f).existsSync())
    .firstOrNull
    ?? (() {
        widget.state.repoFile('index.md').createSync();
        return 'index.md';
    })()
  );

  @override
  void initState() {
    super.initState();

    // Start initialize lenses
    loadExtensions(getGlobalLuaState(), widget.directory).then((_) => setState(() => ready = true));
  }

  Widget leftDrawer(BuildContext context) => LeftDrawer(
    dir: widget.directory,
    openFile: (file) {
      // Close the drawer
      Navigator.pop(context);
      setState(() => note = file);
    },
  );

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Text('Loading');

    return FutureBuilder(
      future: widget.state.getContents(note),
      builder: (context, snapshot) {
        final data = snapshot.data;
        void onUpdate(editor) => widget.state.markModified(note, editor);

        final indexFileRefreshButton = (
          (isExtensionIndexFile(repoRootDirectory, note) && data != null)
          ? IconBtn(
            radius: 8,
            icon: Icons.refresh,
            onPressed: () => runExtensionCode(
              getGlobalLuaState(),
              note,
              StructureParser.fromFileOrDefault(note.path).parse(data),
            ),
          )
          : Container()
        );

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(
              child: Text(note.path.replaceFirst('${widget.directory.path}/', ''))
            ),
            actions: [
              Row(children: [
                  indexFileRefreshButton,
                  const Text('Raw'),
                  Switch(value: raw, onChanged: (b) => setState(() { raw = b; })),
              ]),
            ],
          ),
          drawer: leftDrawer(context),
          body: (
            (snapshot.connectionState != ConnectionState.done) ? const Text('LOADING')
            : (data == null) ? const Text('Null data')
            : NoteEditorWidget(file: note, init: data, markModification: onUpdate, isRaw: raw)
          ),
        );
      },
    );
  }
}
