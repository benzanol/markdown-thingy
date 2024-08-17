import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/file_ops.dart';


const Color directoryColor = Colors.blueGrey;


class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key, required this.dir, this.openFile});
  final Directory dir;
  final Function(File)? openFile;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: (details) async {
      final pos = details.globalPosition;
      final result = await showMenu(
        context: context,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        items: _creationPopupButtons(context, widget.dir),
      );
      result?.call();
    },
    child: Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            widget.dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
            style: const TextStyle(color: directoryColor, fontSize: 35),
          ),
          FileBrowserDirectory(dir: widget.dir, openFile: widget.openFile),
        ],
      ),
    ),
  );
}


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

  void tapEntity(FileSystemEntity entity) {
    if (entity is Directory && openDirs.contains(entity.path)) {
      openDirs.remove(entity.path);
    } else if (entity is Directory) {
      openDirs.add(entity.path);
    } else if (entity is File) {
      widget.openFile?.call(entity);
    }
  }

  Widget _fileNameWidget(FileSystemEntity f) {
    final nameWidget = GestureDetector(
      onTap: () => setState(() => tapEntity(f)),
      child: Text(
        f.uri.pathSegments.lastWhere((seg) => seg.isNotEmpty),
        maxLines: 1,
        style: const TextStyle(fontSize: 20, height: 1.4),
      ),
    );

    return GestureDetector(
      // Create the popup menu
      onLongPressStart: (details) async {
        final pos = details.globalPosition;
        final result = await showMenu(
          context: context,
          position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
          items: <PopupMenuItem<Function()>>[
            ..._creationPopupButtons(context, f is Directory ? f : widget.dir),
            PopupMenuItem(value: () => promptedDelete(context, f), child: const Text('Delete')),
          ],
        );
        result?.call();
      },

      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            f is Directory ? Icons.folder : Icons.insert_drive_file_outlined,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 5),
          nameWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dirs = subDirs;
    final files = subFiles;
    if (dirs == null || files == null) return Container();
    if (dirs.isEmpty && files.isEmpty) return const Text('');

    final rows = [...dirs, ...files].expand((f) => [
        _fileNameWidget(f),
        ...(!(f is Directory && openDirs.contains(f.path)) ? <Widget>[] : [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: FileBrowserDirectory(dir: f, openFile: widget.openFile)
            ),
        ])
    ]);

    return Container(
      padding: const EdgeInsets.only(top: 3, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.toList()
      ),
    );
  }
}

List<PopupMenuItem<Function()>> _creationPopupButtons(BuildContext context, Directory root) => [
  PopupMenuItem(value: () => createFile(context, root), child: const Text('Create File')),
  PopupMenuItem(value: () => createFile(context, root, isDir: true), child: const Text('Create Folder')),
];
