import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/lua_object.dart';


const double luaUiGap = textPadding;
const double luaUiTextSize = 16;
const double luaUiRadius = 6;


class InvalidLuaUiError extends Error {
  InvalidLuaUiError(this.message);
  final String message;
  @override String toString() => message;
}


abstract class LuaUi {
  LuaUi(this.table);
  final LuaTable table;
  List<int> path = [];

  void setPath(List<int> p) => path = p;

  FutureOr<void> performChange(BuildContext context, LuaState lua) {}

  Widget widget(void Function(LuaUi) onChange);

  static LuaUi parse(LuaObject obj) {
    final ui = LuaUi._parse(obj);
    ui.setPath([]);
    return ui;
  }
  static LuaUi _parse(LuaObject obj) {
    if (obj is LuaString) {
      return LuaUi._parse(LuaTable({LuaString('type'): LuaString('label'), LuaNumber(1): obj}));
    }

    final table = ensureLuaTable(obj, 'ui');
    final uiType = ensureLuaString(table['type'] ?? LuaNil(), 'ui.type');

    switch (uiType) {
      case 'label': return LuaLabelUi(table);
      case 'field': return LuaTextFieldUi(table);
      case 'column': return LuaColumnUi(table);
      case 'row': return LuaRowUi(table);
      case 'table': return LuaTableUi(table);
      default: throw InvalidLuaUiError('Invalid ui type: $uiType');
    }
  }
}

class LuaLabelUi extends LuaUi {
  LuaLabelUi(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';

  final String content;
  String? get theme => table['theme']?.value.toString();


  @override
  Future<void> performChange(BuildContext context, LuaState lua) async {
    if (table['picktime']?.type == LuaType.luaFunction) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null) return;

      // Push the function onto the stack
      lua.getField(-1, 'picktime');

      // Push the date object onto the stack
      lua.loadString('return Pl.Date{hour=${time.hour},min=${time.minute}}');
      lua.call(0, 1);

      // Call the picktime function
      lua.call(1, 0);

    } else if (table['onpress']?.type == LuaType.luaFunction) {
      lua.getField(-1, 'onpress');
      lua.call(0, 0);
    }
  }

  @override
  Widget widget(onChange) {
    void onPress() => onChange(this);
    const style = TextStyle(fontSize: luaUiTextSize);
    return (
      theme == 'button' ? ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffeff2ff),
          padding: const EdgeInsets.all(textPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(luaUiRadius),
            side: const BorderSide(
              color: Color(0x771155bb), // Border color
              width: 1.5, // Border width
            ),
          ),
        ),
        onPressed: onPress,
        child: Text(content, style: style),
      )
      : theme == 'icon-button' ? IconButton(icon: Icon(MdiIcons.fromString(content)), onPressed: onPress)
      : GestureDetector(onTap: onPress, child: (
          theme == 'icon' ? Icon(MdiIcons.fromString(content))
          : Text(content, style: style)
        ),
      )
    );
  }
}

class LuaTextFieldUi extends LuaUi {
  LuaTextFieldUi(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';
  String content;


  @override
  void performChange(BuildContext context, LuaState lua) {
    lua.getField(-1, 'onchange');
    // Call the function with the string argument
    if (lua.isFunction(-1)) {
      lua.pushString(content);
      lua.call(1, 0);
    }
  }

  @override
  Widget widget(onChange) => _LongLastingTextField(
    text: content,
    onChange: (newText) {
      content = newText;
      onChange(this);
    },
    maxLines: null,
  );
}

class LuaColumnUi extends LuaUi {
  LuaColumnUi(super.table)
  : children = table.listValues.map(LuaUi._parse).toList();
  final List<LuaUi> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget widget(onChange) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children.map((child) => Padding(
        padding: EdgeInsets.only(bottom: child == children.last ? 0 : luaUiGap),
        child: child.widget(onChange),
    )).toList(),
  );
}

class LuaRowUi extends LuaUi {
  LuaRowUi(super.table)
  : children = table.listValues.map(LuaUi._parse).toList();
  final List<LuaUi> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget widget(onChange) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children.map((child) => Padding(
        padding: EdgeInsets.only(bottom: child == children.last ? 0 : luaUiGap),
        child: child.widget(onChange),
    )).toList()
  );
}

class LuaTableUi extends LuaUi {
  LuaTableUi(super.table)
  : rows = table.listValues.map((row) => (
      row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row'))
      : row.listValues.map(LuaUi._parse).toList()
  )).toList();
  final List<List<LuaUi>> rows;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (rowIdx, row) in rows.indexed) {
      for (final (colIdx, child) in row.indexed) {
        child.setPath([...p, rowIdx, colIdx]);
      }
    }
  }

  @override
  Widget widget(onChange) => Table(
    border: TableBorder.all(),
    defaultColumnWidth: const IntrinsicColumnWidth(),
    children: rows.map((row) => TableRow(
        children: row.map((cell) => TableCell(child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: textPadding, vertical: textPadding/2),
                child: cell.widget(onChange),
              ),
        ))).toList(),
    )).toList()
  );
}


class _LongLastingTextField extends StatefulWidget {
  const _LongLastingTextField({
      required this.text,
      required this.onChange,
      this.maxLines = 1,
  });
  final String text;
  final Function(String) onChange;
  final int? maxLines;

  @override
  State<_LongLastingTextField> createState() => _LongLastingTextFieldState();
}

class _LongLastingTextFieldState extends State<_LongLastingTextField> {
  late final textController = TextEditingController(text: widget.text);
  late final originalField = TextField(
    controller: textController,
    onChanged: onChanged,

    maxLines: widget.maxLines,
    style: const TextStyle(fontSize: luaUiTextSize),
    decoration: const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.all(Radius.circular(luaUiRadius)),
      ),
      contentPadding: EdgeInsets.all(textPadding * 1.4),
      isDense: true,
    ),
  );

  void onChanged(String s) => widget.onChange(s);

  @override
  Widget build(BuildContext context) {
    // If the ui function returned conflicting text, modify the field content
    if (textController.text != widget.text) {
      final cursorPosition = textController.selection.baseOffset;
      textController.text = widget.text;
      textController.selection = TextSelection.fromPosition(
        TextPosition(offset: min(cursorPosition, widget.text.length)),
      );
    }
    return Container(
      alignment: Alignment.topLeft,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 100),
          child: originalField,
        ),
      ),
    );
  }
}
