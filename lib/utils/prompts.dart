import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/editor/repo_file_manager.dart';


Future<String?> promptString(BuildContext context, String question) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: question),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}

Future<bool> promptConfirmation(BuildContext context, String question) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  ).then((confirmed) => confirmed ?? false);
}

Future<void> promptOptions(
  BuildContext context,
  String prompt,
  List<(String, FutureOr<void> Function())> options,
  {bool noCancel = false}
) async {
  final index = await showDialog<int?>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text(prompt),
      actions: options.indexed.map((indexed) => TextButton(
          onPressed: () => Navigator.of(context).pop(indexed.$1),
          child: Text(indexed.$2.$1),
      )).toList(),
    ),
  );

  if (index == null) return;
  await options[index].$2();
}

Future<void> promptOkOk(BuildContext context, String prompt) => (
  promptOptions(context, prompt, [('Ok', () {}), ('Ok', () {})])
);

class PromptOptions extends StatelessWidget {
  const PromptOptions({super.key, this.title, this.content, required this.options});
  final List<(String, Function())> options;
  final String? title;
  final String? content;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title == null ? null : Text(title!),
      content: content == null ? null : Text(content!),
      actions: options.map((option) => TextButton(
          onPressed: () => option.$2(),
          child: Text(option.$1),
      )).toList(),
    );
  }
}


Future<void> promptCreateFile(BuildContext context, NoteHandler handler, String pwd, {
    FileType ft = FileType.file,
}) async {
  final result = await promptString(context, 'File Name');
  if (result == null || result.isEmpty) return;

  final path = concatPaths(pwd, result);
  handler.fs.createOrErr(path, ft: ft);
}

Future<void> promptRenameFile(BuildContext context, NoteHandler handler, String path) async {
  final newName = await promptString(context, 'Rename ${fileName(path)} to:');
  if (newName == null || newName.isEmpty) return;
  handler.fs.renameOrErr(path, newName);
}

Future<void> promptDeleteFile(BuildContext context, NoteHandler handler, String path) async {
  final ft = handler.fs.ensureExists(path);
  final contentsCount = ft.isDir ? handler.fs.listOrErr(path).length : 0;

  final contentsStr = contentsCount == 0 ? '' : ' and $contentsCount sub files';
  final promptStr = 'Are you sure you want to delete ${fileName(path)}$contentsStr?';
  final confirmed = await promptConfirmation(context, promptStr);

  if (confirmed != true) return;
  handler.fs.deleteOrErr(path);
}
