import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/file_ops.dart';


const Color directoryColor = Colors.blueGrey;


class FileBrowser extends StatelessWidget {
  const FileBrowser({super.key, required this.dir, this.openFile});
  final Directory dir;
  final Function(File)? openFile;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onLongPressStart: (details) async {
      final pos = details.globalPosition;
      final result = await showMenu(
        context: context,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        items: _creationPopupButtons(context, dir),
      );
      result?.call();
    },
    child: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            fileName(dir),
            style: const TextStyle(color: directoryColor, fontSize: 35),
          ),
        ),
        FileBrowserDirectory(dir: dir, openFile: openFile),
      ],
    ),
  );
}

class FileBrowserDirectory extends StatefulWidget {
  const FileBrowserDirectory({super.key, required this.dir, this.openFile, this.depth = 0});
  final Directory dir;
  final Function(File)? openFile;
  final int depth;

  @override
  State<FileBrowserDirectory> createState() => _FileBrowserDirectoryState();
}

class _FileBrowserDirectoryState extends State<FileBrowserDirectory> {
  _FileBrowserDirectoryState();

  List<Directory>? subDirs;
  List<File>? subFiles;

  Set<String> openDirs = {};
  FileSystemEntity? hoverFile;

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

  Widget _fileNameWidget(FileSystemEntity f) {
    final nameWidget = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          f is Directory ? Icons.folder : Icons.insert_drive_file_outlined,
          color: Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
        const SizedBox(width: 5),
        Text(
          fileName(f),
          maxLines: 1,
          style: const TextStyle(fontSize: 20, height: 1.4),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Create the popup menu
      onLongPressStart: (details) async {
        final pos = details.globalPosition;
        final result = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
          items: <PopupMenuItem<Function()>>[
            ..._creationPopupButtons(context, f is Directory ? f : widget.dir),
            PopupMenuItem(value: () => renameFile(context, f), child: const Text('Rename')),
            PopupMenuItem(value: () => promptedDelete(context, f), child: const Text('Delete')),
          ],
        );
        result?.call();
      },
      onTap: () => setState(() {
          if (f is Directory && openDirs.contains(f.path)) {
            openDirs.remove(f.path);
          } else if (f is Directory) {
            openDirs.add(f.path);
          } else if (f is File) {
            widget.openFile?.call(f);
          }
      }),

      child: Padding(
        padding: EdgeInsets.only(left: 10 + widget.depth * 10),
        child: nameWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dirs = subDirs;
    final files = subFiles;
    if (dirs == null || files == null) return Container();

    final rows = [...dirs, ...files].expand((f) => [
        _fileNameWidget(f),
        ...(!(f is Directory && openDirs.contains(f.path)) ? <Widget>[] : [
            FileBrowserDirectory(dir: f, openFile: widget.openFile, depth: widget.depth + 1),
        ])
    ]).toList();

    if (rows.isEmpty) rows.add(Container(height: 10));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) async {
        final pos = details.globalPosition;
        final result = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
          items: _creationPopupButtons(context, widget.dir),
        );
        result?.call();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
}

List<PopupMenuItem<Function()>> _creationPopupButtons(BuildContext context, Directory root) => [
  PopupMenuItem(value: () => createFile(context, root), child: const Text('Create File')),
  PopupMenuItem(value: () => createFile(context, root, isDir: true), child: const Text('Create Folder')),
];
