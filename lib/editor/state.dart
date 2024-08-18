import 'dart:async';
import 'dart:io';

import 'package:notes/editor/note_editor.dart';


const Duration saveInterval = Duration(seconds: 1);


class NotesState {
  NotesState({required this.directory}) {
    saveTimer = Timer.periodic(saveInterval, (_) => saveAll());
  }
  final Directory directory;
  late final Timer saveTimer;

  final Map<String, String> _notes = {};
  Map<String, NoteEditor> _modified = {};


  File repoFile(String path) => File.fromUri(directory.uri.resolve(path));

  void markModified(File file, NoteEditor note) => _modified[file.path] = note;

  Future<String> getContents(File file) async {
    final editor = _modified[file.path];
    if (editor != null) return editor.toText();

    final existing = _notes[file.path];
    if (existing != null) return existing;

    final contents = await file.readAsString();
    _notes[file.path] = contents;
    return contents;
  }

  Future<void> saveAll() async {
    if (_modified.isEmpty) return;

    final futures = _modified.entries.map((entry) {
        final content = entry.value.toText();
        _notes[entry.key] = content;
        return File(entry.key).writeAsString(content);
    }).toList();
    _modified = {};
    await Future.wait(futures);
  }
}
