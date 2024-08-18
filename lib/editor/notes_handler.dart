import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/left_drawer.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/state.dart';
import 'package:notes/extensions/lenses.dart';


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
  late File note = widget.state.repoFile('index.md');

  @override
  void initState() {
    super.initState();

    // Start initialize lenses
    loadLenses(widget.directory).then((_) => setState(() => ready = true));
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

    return Scaffold(
      appBar: AppBar(
        // leading: BackButton(onPressed: () => setState(() => noteFile = null)),
        title: Text(note.path.replaceFirst('${widget.directory.path}/', '')),
        actions: [
          Row(children: [
              const Text('Raw'),
              Switch(value: raw, onChanged: (b) => setState(() { raw = b; })),
          ]),
        ],
      ),
      drawer: leftDrawer(context),
      body: FutureBuilder(
        future: widget.state.getContents(note),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text('LOADING');
          }
          final data = snapshot.data;
          if (data == null) return const Text('Null data');
          return NoteEditor(
            init: data,
            onUpdate: (editor) => widget.state.markModified(note, editor),
            raw: raw,
          );
        },
      ),
    );
  }
}
