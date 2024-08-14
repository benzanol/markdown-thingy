import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/left_drawer.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/state.dart';


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

  bool raw = false;
  File? noteFile;

  @override
  void initState() {
    super.initState();

    final indexFile = widget.state.repoFile('index.md');
    if (indexFile.existsSync()) {
      setState(() => noteFile = indexFile);
    }
  }

  Widget leftDrawer() => LeftDrawer(
    dir: widget.directory,
    openFile: (file) => setState(() => noteFile = file),
  );

  @override
  Widget build(BuildContext context) {
    final note = noteFile;
    if (note == null) {
      final controller = TextEditingController();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Do something'),
        ),
        drawer: leftDrawer(),
        body: Column(
          children: [
            TextField(controller: controller),
            ElevatedButton(
              onPressed: () => setState(() => noteFile = File(controller.text)),
              child: Text('Open'),
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // leading: BackButton(onPressed: () => setState(() => noteFile = null)),
        title: Text(note.path.replaceFirst('${widget.directory.path}/', '')),
        actions: [
          Row(children: [
              Text('Raw'),
              Switch(value: raw, onChanged: (b) => setState(() { raw = b; })),
          ]),
        ],
      ),
      drawer: leftDrawer(),
      body: FutureBuilder(
        future: widget.state.getContents(note),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Text('LOADING');
          }
          final data = snapshot.data;
          if (data == null) return Text('Null data');
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
