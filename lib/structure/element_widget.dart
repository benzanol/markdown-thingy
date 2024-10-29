import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/idea.dart';
import 'package:highlight/languages/all.dart';
import 'package:notes/editor/extensions.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/lua/ui.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_widget.dart';
import 'package:notes/utils/fold_button.dart';
import 'package:notes/utils/hscroll.dart';
import 'package:notes/utils/icon_btn.dart';


const double textPadding = 10;


class StructureElementWidget extends StatefulWidget {
  StructureElementWidget({required this.note, required this.element})
  : super(key: GlobalObjectKey(element));
  final NoteEditor note;
  final StructureElement element;

  @override
  // ignore: no_logic_in_create_state
  State<StructureElementWidget> createState() => (
    element is StructureText ? TextElementWidgetState()
    : element is StructureCode ? CodeElementWidgetState()
    : element is StructureTable ? TableElementWidgetState()
    : element is StructureLens ? LensElementWidgetState()
    : (throw 'Invalid structure element type')
  );
}

abstract class StructureElementWidgetState<E extends StructureElement>
extends State<StructureElementWidget> {
  NoteEditor get note => widget.note;
  E get element => widget.element as E;

  bool isFolded = false;

  String get title;
  Widget bodyWidget(BuildContext context);
  Widget leftWidget(BuildContext context) => Container();
  Widget rightWidget(BuildContext context) => Container();

  @override
  void dispose() {
    super.dispose();
    if (note.focused == element || note.focused == this) {
      print('Cancelled focus of $this');
      note.setFocused(null, noRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            title,
            textScaler: const TextScaler.linear(1.2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leftWidget(context),
          FoldButton(isFolded: isFolded, setFolded: (val) => setState(() => isFolded = val)),
          Expanded(child: Container()),
          rightWidget(context),
        ],
      ),
      Visibility(visible: !isFolded, child: bodyWidget(context)),
    ],
  );
}


class TextElementWidgetState extends StructureElementWidgetState<StructureText> {
  @override final String title = 'Text';

  late final field = _TextFieldWrapper(
    init: element.content,
    onEnter: () => note.setFocused(this),
    onChange: (newText) {
      element.content = newText;
      note.markUnsaved();
    },
    focused: () => note.focused == this,
  );

  @override
  Widget bodyWidget(BuildContext context) => _fieldDecoration(context, field, note.focused == this);
}

class CodeElementWidgetState extends StructureElementWidgetState<StructureCode> {
  @override final String title = 'Code';

  late final languageMode = allLanguages[element.language];
  late final controller = CodeController(text: element.content, language: languageMode);
  final focusNode = FocusNode();
  late final _fieldWidget = CodeTheme(
    data: const CodeThemeData(styles: ideaTheme),
    child: CodeField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (newText) {
        element.content = newText;
        note.markUnsaved();
      },
      onTap: () => note.setFocused(this),

      // maxLines: null,
      lineNumberStyle: const LineNumberStyle(width: 35, margin: 5),
      textStyle: const TextStyle(
        fontFamily: 'Iosevka',
        fontFeatures: [FontFeature.fractions()],
      ),
    ),
  );

  Widget? outputWidget;

  @override
  Widget leftWidget(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Text(element.language),
  );

  @override
  Widget rightWidget(BuildContext context) => IconBtn(icon: Icons.play_arrow, onPressed: () {
      try {
        final output = note.handler.lua.executeUserCode(
          element.content,
          pwd: fileParent(note.file),
          context: context,
        );
        setState(() => outputWidget = Text(output.toString()));
      } catch (e) {
        setState(() => outputWidget = Text(e.toString(), style: const TextStyle(color: Colors.red)));
      }
  });

  @override
  Widget bodyWidget(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldDecoration(context, _fieldWidget, note.focused == this),
      outputWidget ?? Container(),
    ],
  );
}

class TableElementWidgetState extends StructureElementWidgetState<StructureTable> {
  @override final String title = 'Table';

  int row = 0;
  int col = 0;
  List<List<String>> get rows => element.table;

  late List<List<TextField>> fields = _createFields();
  List<List<TextField>> _createFields() => (
    element.table.indexed.map((r) => (
        r.$2.indexed.map((cell) => TextField(
            controller: TextEditingController(text: cell.$2),
            focusNode: FocusNode(),
            onChanged: (content) {
              element.table[r.$1][cell.$1] = content;
              note.markUnsaved();
            },
            maxLines: null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: InputBorder.none,
            ),

            onTap: () {
              note.setFocused(this);
              row = r.$1;
              col = cell.$1;
            },
        )).toList()
    )).toList()
  );

  void afterAction() {
    fields = _createFields();
    fields[row][col].focusNode?.requestFocus();
  }

  @override
  Widget bodyWidget(BuildContext context) {
    final table = Hscroll(child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(),
        children: fields.map((fields) => TableRow(
            children: fields.map((field) => TableCell(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 70),
                  child: field,
                ),
            )).toList(),
        )).toList(),
    ));

    return Align(
      alignment: Alignment.topLeft,
      child: _fieldDecoration(context, table, note.focused == this),
    );
  }
}

class LensElementWidgetState extends StructureElementWidgetState<StructureLens> {
  @override final String title = 'Widget';

  _TextFieldWrapper? _rawField; // If raw
  String? _toStateError;
  int? _instanceId;

  LensExtension? get lens => getLens(element.ext, element.name);
  bool get isInteractiveMode => _rawField == null;

  @override void initState() { super.initState(); interactiveMode(); }
  @override void dispose() { super.dispose(); cleanup(); }

  void cleanup() {
    final id = _instanceId;
    if (id != null) note.handler.lua.disposeLensInstance(id);

    _rawField = null;
    _toStateError = null;
    _instanceId = null;
  }

  void interactiveMode() {
    cleanup();

    final lens = this.lens;
    if (lens == null) {
      _toStateError = 'Lens ${element.ext}/${element.name} does not exist';
      return;
    }

    try {
      _instanceId = note.handler.lua.initializeLensInstance(lens, element.text);
    } catch (e) {
      _toStateError = 'Error in $toStateField method: $e';
    }
  }

  void rawMode() {
    cleanup();
    _rawField = _TextFieldWrapper(
      init: element.text,
      onEnter: () => note.setFocused(this),
      onChange: (newText) {
        element.text = newText;
        note.markUnsaved();
      },
      focused: () => note.focused == this,
    );
  }


  Future<void> performLuiAction(LuiComponent component, LuiAction action) async {
    note.handler.lua.pushLuiComponent(_instanceId!, component);
    await action(note.handler.lua);

    // Update the lens element text
    try {
      element.text = note.handler.lua.generateLensText(lens!, _instanceId!);
    } catch (e) {
      print('Error generating widget text: $e');
    }
    note.markUnsaved();
    setState(() {});
  }

  @override
  Widget bodyWidget(BuildContext context) {
    final toStateError = _toStateError;
    final instanceId = _instanceId;
    final rawField = _rawField;
    return (
      rawField != null ? _fieldDecoration(context, rawField, note.focused == this)
      : Container(
        padding: const EdgeInsets.all(vPad),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: fieldBorder,
        ),
        child: (
          toStateError != null ? Text(toStateError, style: const TextStyle(color: Colors.red))
          : instanceId != null ? (
            note.handler.lua.generateLensUi(lens!, instanceId).widget(performLuiAction)
          )
          : throw 'Internal Error: field, error, and instance are all null'
        ),
      )
    );
  }

  @override
  Widget rightWidget(BuildContext context) => Row(
    children: [
      // const Text('Interactive'),
      Switch(value: isInteractiveMode, onChanged: (val) {
          if (val == isInteractiveMode) return;
          setState(() => val ? interactiveMode() : rawMode());
      })
    ],
  );
}


Widget _fieldDecoration(BuildContext context, Widget child, bool focused) => Container(
  decoration: BoxDecoration(
    border: focused ? focusedBorder : fieldBorder,
    color: Theme.of(context).colorScheme.surface,
  ),
  child: child,
);

// Wraps a text field, exposing the FocusNode and TextEditingController
class _TextFieldWrapper extends StatelessWidget {
  _TextFieldWrapper({required this.init, this.onChange, this.onEnter, this.focused});
  final String init;
  final Function(String)? onChange;
  final Function()? onEnter;
  final bool Function()? focused;

  late final controller = TextEditingController(text: init);
  final focusNode = FocusNode();
  late final field = TextField(
    controller: controller,
    focusNode: focusNode,
    // style: null,
    onChanged: onChange,
    onTap: onEnter,

    maxLines: null,
    decoration: const InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.all(textPadding),
    ),
  );

  @override
  Widget build(BuildContext context) => field;
}
