import 'dart:io';

import 'package:flutter/material.dart';


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

  if (fileName == null) return;
  final uri = root.uri.resolve(fileName);

  if (isDir) {
    await Directory.fromUri(uri).create();
  } else {
    await File.fromUri(uri).create();
  }
}

Future<void> promptedDelete(BuildContext context, FileSystemEntity file) async {
  final name = file.uri.pathSegments.lastWhere((seg) => seg.isNotEmpty);
  final contentsCount = file is! Directory ? 0 : file.listSync().length;
  final contentsStr = contentsCount == 0 ? '' : ' and $contentsCount sub files';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text('Are you sure you want to delete $name$contentsStr?'),
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
