import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/with_color.dart';


class FileBrowserDirectory extends StatefulWidget {
  const FileBrowserDirectory({super.key, required this.dir, this.openFile});
  final Directory dir;
  final Function(File)? openFile;

  @override
  State<FileBrowserDirectory> createState() => _FileBrowserDirectoryState();
}

class _FileBrowserDirectoryState extends State<FileBrowserDirectory> {
  _FileBrowserDirectoryState();

  List<Directory>? subDirs;
  List<File>? subFiles;

  Set<String> openDirs = {};

  late StreamSubscription<FileSystemEvent> _listener;

  @override
  void initState() {
    super.initState();
    updateContents();
    _listener = widget.dir.watch().listen((event) => updateContents());
  }

  @override
  void dispose() {
    super.dispose();
    _listener.cancel();
  }

  Future<void> updateContents() async {
    final all = await widget.dir.list().toList();
    setState(() {
        subDirs = all.whereType<Directory>().toList();
        subFiles = all.whereType<File>().toList();
    });
  }

  void tapEntity(FileSystemEntity entity) {
    if (entity is Directory && openDirs.contains(entity.path)) {
      openDirs.remove(entity.path);
    } else if (entity is Directory) {
      openDirs.add(entity.path);
    } else if (entity is File) {
      widget.openFile?.call(entity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirs = subDirs;
    final files = subFiles;
    if (dirs == null || files == null) return Container();
    if (dirs.isEmpty && files.isEmpty) return const Text('');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...dirs, ...files].expand((f) => [
          GestureDetector(
            onTap: () => setState(() => tapEntity(f)),
            child: WithColor(
              color: f is Directory ? Colors.blue : null,
              child: Text(
                f.uri.pathSegments.lastWhere((seg) => seg.isNotEmpty),
                maxLines: 1,
              ),
            ),
          ),
          ...(!(f is Directory && openDirs.contains(f.path)) ? <Widget>[] : [
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 3, bottom: 5),
                child: FileBrowserDirectory(dir: f, openFile: widget.openFile)
              ),
          ])
      ]).toList()
    );
  }
}
