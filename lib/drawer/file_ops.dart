import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/prompts.dart';


String fileName(FileSystemEntity file) => file.uri.pathSegments.lastWhere((seg) => seg.isNotEmpty);

Future<void> createFile(BuildContext context, Directory root, {bool isDir = false}) async {
  final fileName = await promptString(context, 'File Name');

  if (fileName == null || fileName.isEmpty) return;
  final uri = root.uri.resolve(fileName);

  if (isDir) {
    await Directory.fromUri(uri).create();
  } else {
    await File.fromUri(uri).create();
  }
}

Future<void> renameFile(BuildContext context, FileSystemEntity file) async {
  final newName = await promptString(context, 'Rename ${fileName(file)} to:');

  if (newName == null || newName.isEmpty) return;
  await file.rename(file.parent.uri.resolve(newName).path);
}

Future<void> promptedDelete(BuildContext context, FileSystemEntity file) async {
  final contentsCount = file is! Directory ? 0 : file.listSync().length;
  final contentsStr = contentsCount == 0 ? '' : ' and $contentsCount sub files';

  final confirmed = await promptConfirmation(context, 'Are you sure you want to delete ${fileName(file)}$contentsStr?');

  if (confirmed != true) return;
  await file.delete(recursive: true);
}
