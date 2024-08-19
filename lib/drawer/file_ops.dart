import 'dart:io';

import 'package:flutter/material.dart';


String fileName(FileSystemEntity file) => file.uri.pathSegments.lastWhere((seg) => seg.isNotEmpty);

Future<void> createFile(BuildContext context, Directory root, {bool isDir = false}) async {
  final controller = TextEditingController();
  final fileName = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'File name'),
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

  if (fileName == null || fileName.isEmpty) return;
  final uri = root.uri.resolve(fileName);

  if (isDir) {
    await Directory.fromUri(uri).create();
  } else {
    await File.fromUri(uri).create();
  }
}

Future<void> renameFile(BuildContext context, FileSystemEntity file) async {
  final controller = TextEditingController();
  final newName = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: 'Rename ${fileName(file)} to:'),
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

  if (newName == null || newName.isEmpty) return;
  await file.rename(file.parent.uri.resolve(newName).path);
}

Future<void> promptedDelete(BuildContext context, FileSystemEntity file) async {
  final contentsCount = file is! Directory ? 0 : file.listSync().length;
  final contentsStr = contentsCount == 0 ? '' : ' and $contentsCount sub files';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text('Are you sure you want to delete ${fileName(file)}$contentsStr?'),
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
  );

  if (confirmed != true) return;
  await file.delete();
}
