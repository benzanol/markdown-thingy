import 'dart:async';
import 'dart:io';

import 'package:notes/editor/note_editor.dart';


class NotesState {
  NotesState({required this.directory}) {
    saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => saveAll());
  }
  final Directory directory;
  late final Timer saveTimer;

  final Map<String, String> _notes = {};
  Map<String, NoteEditor> _modified = {};


  File getFile(String path) => File('${directory.path}/$path');

  void markModified(String file, NoteEditor note) => _modified[file] = note;

  Future<String> getContents(String path) async {
    final editor = _modified[path];
    if (editor != null) return editor.getText();

    final existing = _notes[path];
    if (existing != null) return existing;

    final contents = await getFile(path).readAsString();
    _notes[path] = contents;
    return contents;
  }

  Future<void> saveAll() async {
    if (_modified.isEmpty) return;

    final futures = _modified.entries.map((entry) {
        final content = entry.value.getText();
        _notes[entry.key] = content;
        return getFile(entry.key).writeAsString(content);
    }).toList();
    _modified = {};
    await Future.wait(futures);
  }
}
