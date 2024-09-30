import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/components/dashed_line.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/lua/lua_ensure.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/structure/lens.dart';


const double luaUiGap = textPadding;
const double luaUiTextSize = 16;
const double luaUiRadius = 6;

const Map<String, Color> colorNames = {
  'white': Colors.white,
  'black': Colors.black,
  'brown': Colors.brown,
  'grey': Colors.grey,
  'gray': Colors.grey,
  'red': Colors.red,
  'blue': Colors.blue,
  'green': Colors.green,
  'yellow': Colors.yellow,
  'purple': Colors.purple,
  'orange': Colors.orange,
};

Color? _parseColor(String? colorStr) => (
  colorStr == null ? null
  : colorStr.startsWith('#') && colorStr.length == 9
  ? Color(int.parse(colorStr.substring(1), radix: 16))
  : colorStr.startsWith('#') && colorStr.length == 7
  ? Color(int.parse('ff${colorStr.substring(1)}', radix: 16))
  : colorNames[colorStr]
);


class InvalidLuaUiError extends Error {
  InvalidLuaUiError(this.message);
  final String message;
  @override String toString() => message;
}


typedef PerformAction = void Function(LuaUi, LuaAction);

abstract class LuaUi {
  static LuaUi parseRoot(LuaObject obj) {
    final ui = LuaUi.parse(obj);
    ui.setPath([]);
    return ui;
  }
  static LuaUi parse(LuaObject obj) {
    if (obj is LuaString) {
      return LuaUi.parse(LuaTable({LuaString('type'): LuaString('label'), LuaNumber(1): obj}));
    }

    final table = ensureLuaTable(obj, 'ui');
    final uiType = ensureLuaString(table['type'] ?? LuaNil(), 'ui.type');

    switch (uiType) {
      case 'empty': return LuaEmptyUi(table);
      case 'label': return LuaLabelUi(table);
      case 'field': return LuaTextFieldUi(table);
      case 'column': return LuaColumnUi(table);
      case 'row': return LuaRowUi(table);
      case 'table': return LuaTableUi(table);
      case 'stack': return LuaStackUi(table);
      default: throw InvalidLuaUiError('Invalid ui type: $uiType');
    }
  }


  LuaUi(this.table);
  final LuaTable table;
  List<int> path = [];

  void setPath(List<int> p) => path = p;

  String? strField(String f) => table[f] == null ? null : ensureLuaString(table[f]!, f);
  num? numField(String f) => table[f] == null ? null : ensureLuaNumber(table[f]!, f);
  double? doubField(String f) => numField(f)?.toDouble();

  T? enumField<T extends Enum>(String field, List<T> values, {List<LuaTable>? tables}) {
    return [...(tables ?? []), table].map((tbl) {
        final tableVal = tbl[field]?.value;
        if (tableVal is! String) return null;
        return values.where((v) => v.name == tableVal).firstOrNull;
    }).where((val) => val != null).firstOrNull;
  }

  Widget innerWidget(PerformAction onChange);
  @nonVirtual
  Widget widget(PerformAction onChange) {
    final p = doubField('p') ?? 0;
    final padding = EdgeInsets.only(
      left:   p + (doubField('pl') ?? 0) + (doubField('px') ?? 0),
      right:  p + (doubField('pr') ?? 0) + (doubField('px') ?? 0),
      top:    p + (doubField('pt') ?? 0) + (doubField('py') ?? 0),
      bottom: p + (doubField('pb') ?? 0) + (doubField('py') ?? 0),
    );

    final container = Container(
      padding: padding,
      color: _parseColor(strField('bg')),
      child: innerWidget(onChange),
    );

    if (table['press']?.type != LuaType.luaFunction) return container;
    return Builder(
      builder: (context) => GestureDetector(
        onTapDown: (TapDownDetails details) {
          final pos = details.localPosition;
          final renderBox = context.findRenderObject() as RenderBox;
          final size = renderBox.size;

          final args = <String, dynamic>{
            'x': pos.dx/size.width,
            'y': pos.dy/size.height,
            'width': size.width,
            'height': size.height,
          };
          onChange(this, (lua) => lua.performPressAction(args));
        },
        child: container,
      ),
    );
  }
}

class LuaEmptyUi extends LuaUi {
  LuaEmptyUi(super.table);

  @override
  Widget innerWidget(PerformAction onChange) => Container();
}

class LuaLabelUi extends LuaUi {
  LuaLabelUi(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';

  final String content;
  String? get theme => table['theme']?.value.toString();
  Color? get fgColor => _parseColor(table['fg']?.value.toString());

  static const buttonFgColor = Color(0xdd2266bb);
  static const buttonBgColor = Color(0xffeff2ff);
  static const buttonBorderColor = Color(0x771155bb);


  @override
  Widget innerWidget(PerformAction onChange) {
    final style = TextStyle(fontSize: luaUiTextSize, color: fgColor);
    final label = (
      theme == 'button' || theme == 'icon-button' ? Transform.scale(
        scale: theme == 'button' ? 1 : 0.85,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: buttonBgColor,
            borderRadius: BorderRadius.circular(theme == 'button' ? luaUiRadius : 100),
            border: const Border.fromBorderSide(BorderSide(
                color: buttonBorderColor, // Border color
                width: 1.5, // Border width
            )),
          ),
          alignment: doubField('width') == null ? null : Alignment.center,
          child: (
            theme == 'button' ? Text(content, style: style.copyWith(color: buttonFgColor))
            : Icon(MdiIcons.fromString(content) ?? Icons.question_mark, color: buttonFgColor)
          ),
        ),
      )
      : theme == 'icon' ? Icon(MdiIcons.fromString(content))
      : Text(content, style: style)
    );
    if (table['fill']?.isTruthy == true) return label;
    return Container(alignment: Alignment.topLeft, child: label);
  }
}

class LuaTextFieldUi extends LuaUi {
  LuaTextFieldUi(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';
  String content;


  @override
  Widget innerWidget(PerformAction onChange) {
    final grow = table['large']?.isTruthy == true;
    return _LongLastingTextField(
      text: content,
      onChange: (newText) {
        content = newText;
        onChange(this, (lua) => lua.performChangeAction(newText));
      },
      grow: grow,
      maxLines: grow ? null : 1,
    );
  }
}

class LuaColumnUi extends LuaUi {
  LuaColumnUi(super.table)
  : children = table.listValues.map(LuaUi.parse).toList();
  final List<LuaUi> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget innerWidget(PerformAction onChange) {
    final align = enumField('align', CrossAxisAlignment.values);
    final gap = doubField('gap') ?? luaUiGap;
    return Column(
      crossAxisAlignment: align ?? CrossAxisAlignment.start,
      children: children.map((child) => Padding(
          padding: EdgeInsets.only(bottom: child == children.last ? 0 : gap),
          child: child.widget(onChange),
      )).toList(),
    );
  }
}

class LuaRowUi extends LuaUi {
  LuaRowUi(super.table)
  : children = table.listValues.map(LuaUi.parse).toList();
  final List<LuaUi> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget innerWidget(PerformAction onChange) {
    final expanded = table['expanded']?.isTruthy == true;
    final align = enumField('align', CrossAxisAlignment.values);
    final gap = doubField('gap') ?? luaUiGap;
    final row = Row(
      crossAxisAlignment: align ?? CrossAxisAlignment.start,
      children: children.map((child) {
          final inside = Padding(
            padding: EdgeInsets.only(right: child == children.last ? 0 : gap),
            child: child.widget(onChange),
          );
          return expanded ? Expanded(child: inside) : inside;
      }).toList()
    );

    if (expanded) return row;
    return Hscroll(child: row);
  }
}

class LuaTableUi extends LuaUi {
  LuaTableUi(super.table)
  : rows = table.listValues.map((row) => (
      table: row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row')) : row,
      // ignore: unnecessary_cast
      cells: (row as LuaTable).listValues.map(LuaUi.parse).toList()
  )).toList();
  final List<({LuaTable table, List<LuaUi> cells})> rows;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (rowIdx, row) in rows.indexed) {
      for (final (colIdx, child) in row.cells.indexed) {
        child.setPath([...p, rowIdx, colIdx]);
      }
    }
  }

  @override
  Widget innerWidget(PerformAction onChange) => Table(
    border: TableBorder.all(),
    defaultColumnWidth: const IntrinsicColumnWidth(),
    children: rows.map((row) => TableRow(
        children: row.cells.map((cell) => TableCell(
            verticalAlignment: enumField('align', TableCellVerticalAlignment.values, tables: [cell.table, row.table]),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: textPadding, vertical: textPadding/2),
                child: cell.widget(onChange),
              ),
            )
        )).toList(),
    )).toList()
  );
}

class LuaStackUi extends LuaUi {
  LuaStackUi(super.table) {
    for (final t in table.listValues.whereType<LuaTable>()) {
      if (t['type']?.value == 'line') {
        lines.add(LuaEmptyUi(t));
      } else {
        children.add(LuaUi.parse(t));
      }
    }
  }
  final List<LuaUi> children = [];
  final List<LuaEmptyUi> lines = [];

  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  static double? dimension(num? raw, double max) => (
    raw == null ? null
    : raw is int ? raw.toDouble()
    : raw.toDouble() * max
  );

  static Positioned generateChildWidget(LuaUi child, PerformAction onChange, BoxConstraints box) {
    return Positioned(
      left: dimension(child.numField('x'), box.maxWidth),
      top: dimension(child.numField('y'), box.maxHeight),
      width: dimension(child.numField('width'), box.maxWidth),
      height: dimension(child.numField('height'), box.maxHeight),
      child: child.widget(onChange),
    );
  }

  static Positioned generateLineWidget(LuaUi line, PerformAction onChange, BoxConstraints box) {
    final w = dimension(line.numField('width'), box.maxWidth);
    final h = dimension(line.numField('height'), box.maxHeight);
    return Positioned(
      left: dimension(line.numField('x'), box.maxWidth),
      top: dimension(line.numField('y'), box.maxHeight),
      child: DashedLine(
        length: w ?? h ?? (throw 'Line has no width or height'),
        isVertical: w == null,
        color: _parseColor(line.strField('color')) ?? Colors.black,
        thickness: line.doubField('thickness') ?? 1,
        style: line.enumField('style', DashedLineStyle.values) ?? DashedLineStyle.solid,
      ),
    );
  }

  @override
  Widget innerWidget(PerformAction onChange) => SizedBox(
    height: doubField('height') ?? 100,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          ...children.map((child) => generateChildWidget(child, onChange, constraints)),
          ...lines.map((child) => generateLineWidget(child, onChange, constraints)),
        ],
      ),
    ),
  );

}


class _LongLastingTextField extends StatefulWidget {
  const _LongLastingTextField({
      required this.text,
      required this.onChange,
      this.grow = false,
      this.maxLines = 1,
  });
  final String text;
  final Function(String) onChange;
  final bool grow;
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
      contentPadding: EdgeInsets.all(textPadding),
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

    if (widget.grow) {
      return originalField;
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
