import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/drawer/git.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/utils/icon_btn.dart';
import 'package:notes/utils/prompts.dart';


const Color directoryColor = Colors.blueGrey;
const double dirEndPadding = 3;


typedef _PopupButton = PopupMenuItem<Function(BuildContext context)>;


class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key, required this.handler, required this.dir, required this.openFile});
  final NoteHandler handler;
  final String dir;
  final Function(String file) openFile;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  Map<String, StreamSubscription<FileSystemEvent>> openDirs = {};
  void setDirOpen(String dir) => openDirs[dir] = widget.handler.fs.dirWatcher(dir, () => setState(() {}));
  void setDirClosed(String dir) => openDirs.remove(dir)?.cancel();

  @override void initState() { super.initState(); setDirOpen(widget.dir); }
  @override void dispose() { super.dispose(); openDirs.keys.toList().forEach(setDirClosed); }


  List<_PopupButton> creationPopupButtons(String pwd) => [
    PopupMenuItem(
      value: (context) => promptCreateFile(context, widget.handler, pwd),
      child: const Text('Create File'),
    ),
    PopupMenuItem(
      value: (context) => promptCreateFile(context, widget.handler, pwd, ft: FileType.directory),
      child: const Text('Create Folder'),
    ),
  ];

  Future<void> showPopup(BuildContext context, Offset pos, List<_PopupButton> items) {
    return showMenu(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: items,
    ).then((result) => result?.call(context));
  }


  Widget fileNameWidget(String path, FileType ft, int depth, bool dirEnd) {
    final nameWidget = Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          ft.isDir ? Icons.folder : Icons.insert_drive_file_outlined,
          color: Theme.of(context).colorScheme.secondary,
          size: 20,
        ),
        const SizedBox(width: 5),
        Text(
          fileName(path),
          maxLines: 1,
          style: const TextStyle(fontSize: 20, height: 1.4),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => showPopup(context, details.globalPosition, [
          ...creationPopupButtons(fileParent(path)),
          PopupMenuItem(value: (context) => promptRenameFile(context, widget.handler, path), child: const Text('Rename')),
          PopupMenuItem(value: (context) => promptDeleteFile(context, widget.handler, path), child: const Text('Delete')),
      ]),
      onTap: () => setState(() {
          if (ft.isDir && openDirs.containsKey(path)) {
            setDirClosed(path);
          } else if (ft.isDir) {
            setDirOpen(path);
          } else if (ft.isFile) {
            widget.openFile(path);
          }
      }),

      child: Padding(
        padding: EdgeInsets.only(left: 10 + depth * 10, bottom: dirEnd ? dirEndPadding : 0),
        child: nameWidget,
      ),
    );
  }

  Widget directoryContentsWidget(String path, int depth) {
    final children = widget.handler.fs.listOrErr(path);

    // Sort based on file type, then based on name
    int ftPriority(FileType ft) => ft.isDir ? 0 : 1;
    children.sort((a, b) {
        final compareFt = ftPriority(a.$2).compareTo(ftPriority(b.$2));
        return compareFt != 0 ? compareFt : a.$1.compareTo(b.$1);
    });

    // Return a small gesture detector that still takes up a little bit of space
    if (children.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => showPopup(context, details.globalPosition, creationPopupButtons(path)),
        child: Container(height: 20),
      );
    }

    return Column(
      children: children.expand((child) {
          final childPath = concatPaths(path, child.$1);
          final isOpen = openDirs.containsKey(childPath);
          return [
            fileNameWidget(childPath, child.$2, depth, child == children.last && !isOpen),
            isOpen ? directoryContentsWidget(childPath, depth+1) : Container(),
          ];
      }).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final titleWidget = Row(
      children: [
        const SizedBox(width: 10),
        Text(
          fileName('Repo'),
          style: const TextStyle(color: directoryColor, fontSize: 35),
        ),
        const SizedBox(width: 15),
        IconBtn(icon: MdiIcons.git, scale: 1.1, onPressed: () => showGitSyncMenu(context, widget.handler)),
      ],
    );

    final browserWidget = ListView(
      shrinkWrap: true,
      children: [titleWidget, directoryContentsWidget(widget.dir, 0)],
    );

    final bigGestureDetector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => showPopup(context, details.globalPosition, creationPopupButtons(widget.dir)),
    );

    return Stack(children: [bigGestureDetector, browserWidget]);
  }
}
