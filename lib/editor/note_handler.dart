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
  late final LuaContext lua = LuaContext.handler(this);

  GithubRepo? git;

  late NoteEditor note;
  late List<String> history;
  int historyIdx = 0;

  (NoteEditor, Object)? focused; // StructureHeading | StructureElement | TextEdittingController | CodeController
  void setFocused((NoteEditor, Object)? newFocus, {bool noRefresh = false}) {
    print('Focused: $newFocus');
    if (newFocus == focused) return;
    focused = newFocus;
    if (!noRefresh) refreshWidget();
  }


  void refreshWidget() {
    final state = GlobalObjectKey(this).currentState;
    if (state is _NoteHandlerWidgetState) state.refresh();
  }

  void historyMove(int n) {
    historyIdx = (historyIdx + n).clamp(0, history.length-1);
  }

  void openFile(String newFile) {
    // Cut off redo list
    history.removeRange(historyIdx+1, history.length);
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

  List<IconBtn> leftActions(BuildContext context) => [
    IconBtn(
      icon: MdiIcons.menu, padding: 5,
      onPressed: () => Scaffold.of(context).openDrawer(),
    ),
    IconBtn(
      icon: Icons.arrow_back, padding: 5,
      onPressed: handler.historyIdx == 0 ? null : () => handler.historyMove(-1),
    ),
    IconBtn(
      icon: Icons.arrow_forward, padding: 5,
      onPressed: handler.historyIdx == handler.history.length-1 ? null : () => handler.historyMove(1),
    ),
  ];

  List<Widget> rightActions() {
    const double buttonPadding = 4;

    final saveBtn = !handler.note.unsaved ? null : IconBtn(
      padding: buttonPadding,
      icon: Icons.save,
      onPressed: () => handler.note.save(),
    );

    final ext = isExtensionIndexFile(handler, handler.note.file);
    final refreshBtn = ext == null ? null : IconBtn(
      padding: buttonPadding,
      icon: Icons.refresh,
      onPressed: () => handler.lua.executeExtensionCode(ext, handler.note.struct.getLuaCode()),
    );

    return [
      saveBtn ?? Container(),
      refreshBtn ?? Container(),
      const Padding(padding: EdgeInsets.all(3), child: Text('Raw')),
      Switch(value: handler.note.isRaw, onChanged: handler.note.setRaw),
    ];
  }

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
        leadingWidth: 110,
        title: FittedBox(child: Text(handler.note.file)),
        actions: rightActions(),
      ),
      drawer: LeftDrawer(child:
        FileBrowser(
          handler: handler,
          dir: '',
          openFile: (file) {
            handler.openFile(file);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: bodyWithActions,
    );
  }
}
