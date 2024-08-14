import 'dart:io';

import 'package:flutter/material.dart';
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
  String? note;

  @override
  Widget build(BuildContext context) {
    final notePath = note;
    if (notePath == null) {
      final controller = TextEditingController();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Do something'),
        ),
        body: Column(
          children: [
            TextField(controller: controller),
            ElevatedButton(
              onPressed: () => setState(() => note = controller.text),
              child: Text('Open'),
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => setState(() => note = null)),
        title: Text(notePath),
        actions: [
          Row(children: [
              Text('Raw'),
              Switch(value: raw, onChanged: (b) => setState(() { raw = b; })),
          ]),
        ],
      ),
      body: FutureBuilder(
        future: widget.state.getContents(notePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Text('LOADING');
          }
          final data = snapshot.data;
          if (data == null) return Text('Null data');
          return NoteEditor(
            init: data,
            onUpdate: (editor) => widget.state.markModified(notePath, editor),
            raw: raw,
          );
        },
      ),
    );
  }
}
