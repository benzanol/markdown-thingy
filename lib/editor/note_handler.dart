import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/drawer/file_browser.dart';
import 'package:notes/drawer/git.dart';
import 'package:notes/drawer/left_drawer.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/extensions.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/utils/icon_btn.dart';
import 'package:notes/utils/search.dart';


const List<String> initFiles = ['index.org', 'index.md'];
String _openOrCreateInitFile(NoteHandler handler) {
  final existing = initFiles.where((f) => handler.fs.existsFile(f)).firstOrNull;
  if (existing != null) return existing;

  handler.fs.createOrErr(initFiles[0]);
  return initFiles[0];
}


class NoteHandler {
  NoteHandler({required Directory root}) : fs = RepoFileManager(root) {
    final init = _openOrCreateInitFile(this);
    note = NoteEditor(handler: this, file: init);
    history = [init];
  }

  final RepoFileManager fs;
  late final LuaContext lua = LuaContext.init(this);

  GithubRepo? git;

  late NoteEditor note;
  late List<String> history;
  int historyIdx = 0;

  final Set<String> openDirs = {''};

  (NoteEditor, Object)? focused; // StructureHeading | StructureElement | TextEdittingController | CodeController
  void setFocused((NoteEditor, Object)? newFocus, {bool noRefresh = false}) {
    // print('Focused: $newFocus');
    if (newFocus == focused) return;
    focused = newFocus;
    if (!noRefresh) refreshWidget();
  }


  void refreshWidget() {
    final state = GlobalObjectKey(this).currentState;
    if (state is _NoteHandlerWidgetState) state.refresh();
  }

  void historyMove(int n) {
    final oldIdx = historyIdx;
    historyIdx = (historyIdx + n).clamp(0, history.length-1);
    if (oldIdx == historyIdx) return;

    note = NoteEditor(handler: this, file: history[historyIdx]);
    refreshWidget();
  }

  void openFile(String newFile) {
    note.save();

    // Reverse redos
    final ahead = history.sublist(historyIdx, history.length);
    history.removeRange(historyIdx, history.length);
    history.addAll(ahead.reversed);

    // Remove duplicates
    history.removeWhere((p) => p == newFile);

    history.add(newFile);
    historyIdx = history.length - 1;

    note = NoteEditor(handler: this, file: newFile);
    refreshWidget();
  }
}


class NoteHandlerWidget extends StatefulWidget {
  NoteHandlerWidget({required this.handler}) : super(key: GlobalObjectKey(handler));
  final NoteHandler handler;

  @override
  State<NoteHandlerWidget> createState() => _NoteHandlerWidgetState();
}

class _NoteHandlerWidgetState extends State<NoteHandlerWidget> {
  NoteHandler get handler => widget.handler;

  void refresh() => setState(() {});

  static const double iconButtonPadding = 5;
  List<IconBtn> leftActions(BuildContext context) => [
    IconBtn(
      icon: MdiIcons.menu, padding: iconButtonPadding,
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
    IconBtn(
      icon: Icons.search, padding: iconButtonPadding,
      onPressed: () => promptRecentFiles(context),
    )
  ];

  List<Widget> rightActions() {
    const double buttonPadding = 4;

    final saveBtn = !handler.note.unsaved ? null : IconBtn(
      padding: buttonPadding,
      icon: Icons.save,
      onPressed: () => handler.note.save(),
    );

    final ext = extensionOfFile(handler, handler.note.file);
    final refreshBtn = ext == null ? null : IconBtn(
      padding: buttonPadding,
      icon: Icons.refresh,
      onPressed: () => handler.lua.executeExtensionCode(ext, handler.note.struct.getLuaCode()),
    );

    return [
      saveBtn ?? Container(),
      refreshBtn ?? Container(),
      Switch(value: !handler.note.isRaw, onChanged: (v) => handler.note.setRaw(!v)),
    ];
  }

  void promptRecentFiles(BuildContext context) => showDialog(
    context: context,
    builder: (context) => SearchMenu(
      onSelect: (file) => handler.openFile(file),
      options: handler.fs.listAllFiles().map((f) => f.substring(1, f.length)).toList(),
      initial: handler.history.reversed.toList(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget? actionBar;
    final f = handler.focused;
    if (f != null) {
      actionBar = currentActionBar(
        context: context, note: f.$1, object: f.$2,
        setFocus: (obj) => handler.setFocused(obj == null ? null : (f.$1, obj)),
        after: () {
          handler.refreshWidget();
          f.$1.markUnsaved();
        },
      );
    }

    final body = NoteEditorWidget(note: handler.note);
    final bodyWithActions = actionBar == null ? body : Column(
      children: [
        Expanded(child: body),
        // Wrap in a builder so that the action bar gets created AFTER a
        // focusedElement gets initialized
        Builder(builder: (context) => Container(
            color: Theme.of(context).colorScheme.secondary,
            child: actionBar,
        )),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (context) => Row(children: leftActions(context))),
        leadingWidth: 70,
        title: FittedBox(child: Text(handler.note.file)),
        actions: rightActions(),
      ),
      drawer: LeftDrawer(child: FileBrowser(
          handler: handler,
          dir: '',
          openDirs: handler.openDirs,
          openFn: (context, file) {
            handler.openFile(file);
            Navigator.of(context).pop();
          },
      )),
      body: bodyWithActions,
    );
  }
}
