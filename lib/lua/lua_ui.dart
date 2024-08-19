import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/lua/functions.dart';
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
  List<int> path = [];
  void setPath(List<int> p) => path = p;

  void performChange(LuaState lua) {}

  Widget widget(void Function(LuaUi) onChange);

  static LuaUi parse(LuaObject obj) {
    final ui = LuaUi._parse(obj);
    ui.setPath([]);
    return ui;
  }
  static LuaUi _parse(LuaObject obj) {
    final table = ensureLuaTable(obj);
    final uiType = ensureLuaString(table['type'], field: 'type');

    switch (uiType) {
      case 'field': return LuaTextFieldUi(table.listValues.firstOrNull?.value?.toString() ?? '');
      case 'label': return LuaLabelUi(
        table.listValues.firstOrNull?.value?.toString() ?? '',
        theme: table['theme']?.value?.toString(),
      );

      case 'column': return LuaColumnUi(table.listValues.map(LuaUi._parse).toList());
      case 'row': return LuaRowUi(table.listValues.map(LuaUi._parse).toList());
      case 'table': return LuaTableUi(
        table.listValues.map((row) => (
            row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row'))
            : row.listValues.map(LuaUi._parse).toList()
        )).toList()
      );

      default: throw InvalidLuaUiError('Invalid ui type: $uiType');
    }
  }
}

class LuaLabelUi extends LuaUi {
  LuaLabelUi(this.text, {this.theme});
  final String text;
  final String? theme;

  @override
  void performChange(LuaState lua) {
    lua.getField(-1, 'onPress');
    if (lua.isFunction(-1)) {
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
        child: Text(text, style: style),
      )
      : theme == 'icon-button' ? IconButton(icon: Icon(MdiIcons.fromString(text)), onPressed: onPress)
      : GestureDetector(onTap: onPress, child: (
          theme == 'icon' ? Icon(MdiIcons.fromString(text))
          : Text(text, style: style)
        ),
      )
    );
  }
}

class LuaTextFieldUi extends LuaUi {
  LuaTextFieldUi(this.text);
  String text;

  @override
  void performChange(LuaState lua) {
    lua.getField(-1, 'onChange');
    // Call the function with the string argument
    if (lua.isFunction(-1)) {
      lua.pushString(text);
      lua.call(1, 0);
    }
  }

  @override
  Widget widget(onChange) => _LongLastingTextField(
    text: text,
    onChange: (newText) {
      text = newText;
      onChange(this);
    },
  );
}

class LuaColumnUi extends LuaUi {
  LuaColumnUi(this.children);
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
  LuaRowUi(this.children);
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
  LuaTableUi(this.rows);
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
        children: row.map((cell) => TableCell(child: cell.widget(onChange))).toList(),
    )).toList()
  );
}


class _LongLastingTextField extends StatefulWidget {
  const _LongLastingTextField({required this.text, required this.onChange});
  final String text;
  final Function(String) onChange;

  @override
  State<_LongLastingTextField> createState() => _LongLastingTextFieldState();
}

class _LongLastingTextFieldState extends State<_LongLastingTextField> {
  late final textController = TextEditingController(text: widget.text);
  late final originalField = TextField(
    controller: textController,
    onChanged: onChanged,
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
