import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/file_ops.dart';
import 'package:notes/drawer/git_manager.dart';


const Color directoryColor = Colors.blueGrey;


class FileBrowserState {
  FileBrowserState({required this.root, required this.open, required this.git});
  final Directory root;
  final List<String> open;
  final GitStatus git;
}


class FileBrowser extends StatelessWidget {
  const FileBrowser({super.key, required this.state, required this.openFile});
  final FileBrowserState state;
  final Function(File)? openFile;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              fileName(state.root),
              style: const TextStyle(color: directoryColor, fontSize: 35),
            ),
          ),
          state.git.widget(),
        ],
      ),
      _FileBrowserDirectory(dir: state.root, browser: this),
    ],
  );
}


class _FileBrowserDirectory extends StatefulWidget {
  const _FileBrowserDirectory({required this.dir, required this.browser, this.depth = 0});
  final Directory dir;
  final FileBrowser browser;
  final int depth;

  @override
  State<_FileBrowserDirectory> createState() => _FileBrowserDirectoryState();
}

class _FileBrowserDirectoryState extends State<_FileBrowserDirectory> {
  _FileBrowserDirectoryState();

  Directory get root => widget.browser.state.root;
  List<String> get open => widget.browser.state.open;

  List<Directory>? subDirs;
  List<File>? subFiles;

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
          if (f is Directory && open.contains(f.path)) {
            open.remove(f.path);
          } else if (f is Directory) {
            open.add(f.path);
          } else if (f is File) {
            widget.browser.openFile?.call(f);
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
        ...(!(f is Directory && open.contains(f.path)) ? <Widget>[] : [
            _FileBrowserDirectory(dir: f, browser: widget.browser, depth: widget.depth + 1),
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
