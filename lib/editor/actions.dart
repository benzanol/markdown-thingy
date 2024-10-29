import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/element_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/utils/prompts.dart';
import 'package:notes/utils/with_color.dart';


class EditorActionProps<Obj> {
  EditorActionProps({required this.obj, required this.note, required this.context})
  : newFocus = obj;
  final Obj obj;
  final NoteEditor note;
  final BuildContext context;

  Object? newFocus;
}

typedef EditorAction<Obj> = (IconData, FutureOr<void> Function(EditorActionProps<Obj> ps));
class EditorActionBar<Obj> {
  const EditorActionBar({
      required this.actions,
      this.maintainFocus,
  });
  final List<EditorAction<Obj>> actions;
  final Function(EditorActionProps<Obj> ps)? maintainFocus;

  static const double size = 32;
  static const double pad = 8;
  Widget widget({
      required BuildContext context,
      required NoteEditor note,
      required Obj object,
      required Function(Object?) setFocus,
      required Function() after,
  }) {
    final buttons = actions.map((action) => MaterialButton(
        padding: EdgeInsets.zero,
        minWidth: 0,
        onPressed: () async {
          final ps = EditorActionProps(obj: object, note: note, context: context);
          await action.$2(ps);

          if (ps.newFocus == object) {
            maintainFocus?.call(ps);
          } else {
            setFocus(ps.newFocus);
          }
          after();
        },
        child: WithColor(
          color: Theme.of(context).colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.all(pad),
            child: Icon(action.$1, size: size),
          ),
        ),
    )).toList();

    return Container(
      color: Theme.of(context).colorScheme.secondary,
      child: Row(children: buttons),
    );
  }
}


Widget? currentActionBar({
    required BuildContext context,
    required NoteEditor note,
    required Object object,
    required Function(Object?) setFocus,
    required Function() after,
}) {
  Widget widget<Obj>(EditorActionBar<Obj> bar, Obj obj) => (
    bar.widget(context: context, note: note, object: obj, after: after, setFocus: setFocus)
  );

  return (
    object is TextElementWidgetState ? widget<TextElementWidgetState>(textActionsBar, object)
    : object is CodeElementWidgetState ? widget<CodeElementWidgetState>(codeActionsBar, object)
    : object is TableElementWidgetState ? widget<TableElementWidgetState>(tableActionsBar, object)
    : object is StructureHeading ? widget<StructureHeading>(headingActions, object)
    : object is StructureElement ? widget<StructureElement>(elementActions, object)
    : null
  );
}


void _surroundSelection(TextEditingController controller, String startTag, String endTag) {
  final selection = controller.selection;
  final text = controller.text;
  final start = selection.start;
  final end = selection.end;

  final before = text.substring(0, start);
  final selectedText = text.substring(start, end);
  final after = text.substring(end);

  final newText = '$before$startTag$selectedText$endTag$after';
  controller.text = newText;
  controller.selection = TextSelection.collapsed(offset: end + startTag.length);
}

final textActionsBar = EditorActionBar<TextElementWidgetState>(
  maintainFocus: (ps) => ps.obj.field.focusNode.requestFocus(),
  actions: [
    (Icons.exit_to_app, (ps) => ps.newFocus = ps.obj.element),
    (Icons.format_italic, (ps) => _surroundSelection(ps.obj.field.controller, '*', '*')),
    (Icons.format_bold, (ps) => _surroundSelection(ps.obj.field.controller, '**', '**')),
    (Icons.format_underline, (ps) => _surroundSelection(ps.obj.field.controller, '_', '_')),
  ],
);

final codeActionsBar = EditorActionBar<CodeElementWidgetState>(
  actions: [
    (Icons.exit_to_app, (ps) => ps.newFocus = ps.obj.element),
    (Icons.circle_outlined, (ps) => _surroundSelection(ps.obj.controller, '(', ')')),
    (Icons.data_array, (ps) => _surroundSelection(ps.obj.controller, '[', ']')),
    (Icons.data_object, (ps) => _surroundSelection(ps.obj.controller, '{', '}')),
    (Icons.code, (ps) => _surroundSelection(ps.obj.controller, '<', '>')),
  ],
);

final tableActionsBar = EditorActionBar<TableElementWidgetState>(
  maintainFocus: (ps) => ps.obj.afterAction(),
  actions: [
    (Icons.exit_to_app, (ps) => ps.newFocus = ps.obj.element),

    (MdiIcons.tableRowPlusBefore, (ps) {
        ps.obj.rows.insert(ps.obj.row, List.generate(ps.obj.rows[0].length, (_) => ''));
    }),
    (MdiIcons.tableRowPlusAfter, (ps) {
        ps.obj.rows.insert(ps.obj.row + 1, List.generate(ps.obj.rows[0].length, (_) => ''));
        ps.obj.row++;
    }),
    (MdiIcons.tableRowRemove, (ps) {
        if (ps.obj.rows.length == 1) return;
        ps.obj.rows.removeAt(ps.obj.row);
        if (ps.obj.row >= ps.obj.rows.length) ps.obj.row--;
    }),

    (MdiIcons.tableColumnPlusBefore, (ps) {
        for (final row in ps.obj.rows) {
          row.insert(ps.obj.col, '');
        }
    }),
    (MdiIcons.tableColumnPlusAfter, (ps) {
        for (final row in ps.obj.rows) {
          row.insert(ps.obj.col+1, '');
        }
        ps.obj.col++;
    }),
    (MdiIcons.tableColumnRemove, (ps) {
        if (ps.obj.rows[0].length == 1) return;
        for (final row in ps.obj.rows) {
          row.removeAt(ps.obj.col);
        }
        if (ps.obj.col >= ps.obj.rows[0].length) ps.obj.col--;
    }),
  ],
);


StructureHeading createHeading() => StructureHeading(
  title: 'Untitled Heading',
  body: Structure.empty(),
);

final List<(IconData, StructureElement Function())> elementBuilders = [
  (Icons.code, () => StructureCode('', language: 'lua')),
  (Icons.description, () => StructureText('')),
  (MdiIcons.table, () => StructureTable([['', ''], ['', '']])),
];

final headingActions = EditorActionBar<StructureHeading>(
  actions: [
    (Icons.delete, (ps) async {
        if (!await promptConfirmation(ps.context, 'Delete ${ps.obj.title}?')) return;
        final path = ps.note.struct.searchStruct(ps.obj.body);
        if (path == null || path.isEmpty) return;
        final headings = ps.note.struct.follow(path.sublist(0, path.length-1)).headings;
        headings.removeAt(path.last);
        // Select the next heading
        ps.newFocus = headings.isEmpty ? null : headings[min(headings.length-1, path.last)];
    }),
    (Icons.edit, (ps) async {
        final newName = await promptString(ps.context, 'Rename ${ps.obj.title} to:');
        if (newName != null)  ps.obj.title = newName;
    }),
    (Icons.title, (ps) {
        final path = ps.note.struct.searchStruct(ps.obj.body);
        if (path == null || path.isEmpty) return;
        final newHeading = createHeading();
        ps.note.struct.follow(path.sublist(0, path.length-1)).headings.insert(path.last, newHeading);
        ps.newFocus = newHeading;
    }),
    (
      Icons.format_indent_increase,
      (ps) => ps.obj.body.headings.insert(0, createHeading()),
    ),
    ...elementBuilders.map((action) => (action.$1, (ps) {
          final newElem = action.$2();
          ps.obj.body.content.insert(0, newElem);
          ps.newFocus = newElem;
    })),
  ],
);

final elementActions = EditorActionBar<StructureElement>(
  actions: [
    (Icons.delete, (ps) async {
        if (!await promptConfirmation(ps.context, 'Delete element?')) return;
        final (path, idx) = ps.note.struct.searchElement(ps.obj)!;
        final elems = ps.note.struct.follow(path).content;
        elems.removeAt(idx);
        ps.newFocus = elems.isEmpty ? null : elems[min(idx, elems.length-1)];
    }),
    ...elementBuilders.map((builder) => (
        builder.$1,
        (ps) {
          final newElem = builder.$2();
          final (path, idx) = ps.note.struct.searchElement(ps.obj)!;
          ps.note.struct.follow(path).content.insert(idx+1, newElem);
          ps.newFocus = newElem;
        },
    )),
  ]
);
