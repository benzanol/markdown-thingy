import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/utils/dashed_line.dart';
import 'package:notes/utils/hscroll.dart';
import 'package:notes/lua/ensure.dart';
import 'package:notes/lua/object.dart';


const double luaUiGap = 8;
const double luaUiPad = 8;
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


// A ui action is either a button press or a text field change
typedef LuiAction = FutureOr<void> Function(LuaContext lua);
typedef PerformUiAction = void Function(LuiComponent component, LuiAction action);

abstract class LuiComponent {
  static LuiComponent parse(LuaObject obj) {
    final ui = LuiComponent._parseRec(obj);
    ui.setPath([]);
    return ui;
  }
  static LuiComponent _parseRec(LuaObject obj) {
    if (obj is LuaString) {
      return LuiComponent._parseRec(LuaTable({LuaString('type'): LuaString('label'), LuaNumber(1): obj}));
    }

    final table = ensureLuaTable(obj, 'ui');
    final uiType = ensureLuaString(table['type'] ?? LuaNil(), 'ui.type');

    switch (uiType) {
      case 'empty': return LuiEmpty(table);
      case 'label': return LuiLabel(table);
      case 'field': return LuiTextField(table);
      case 'column': return LuiColumn(table);
      case 'row': return LuiRow(table);
      case 'table': return LuiTable(table);
      case 'stack': return LuiStack(table);
      default: throw InvalidLuaUiError('Invalid ui type: $uiType');
    }
  }


  LuiComponent(this.table);
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

  Widget innerWidget(PerformUiAction performAction);
  @nonVirtual
  Widget widget(PerformUiAction performAction) {
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
      child: innerWidget(performAction),
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
          performAction(this, (lua) => lua.performPressAction(args, context));
        },
        child: container,
      ),
    );
  }
}

class LuiEmpty extends LuiComponent {
  LuiEmpty(super.table);

  @override
  Widget innerWidget(PerformUiAction performAction) => Container();
}

class LuiLabel extends LuiComponent {
  LuiLabel(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';

  final String content;
  String? get theme => table['theme']?.value.toString();
  Color? get fgColor => _parseColor(table['fg']?.value.toString());

  static const buttonFgColor = Color(0xdd2266bb);
  static const buttonBgColor = Color(0xffeff2ff);
  static const buttonBorderColor = Color(0x771155bb);


  @override
  Widget innerWidget(PerformUiAction performAction) {
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
            theme == 'button'
            ? Text(
              content,
              style: style.copyWith(color: buttonFgColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
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

class LuiTextField extends LuiComponent {
  LuiTextField(super.table)
  : content = table.listValues.firstOrNull?.value?.toString() ?? '';
  String content;


  @override
  Widget innerWidget(PerformUiAction performAction) {
    final grow = table['large']?.isTruthy == true;
    return _LongLastingTextField(
      text: content,
      onChange: (newText) {
        content = newText;
        performAction(this, (lua) => lua.performChangeAction(newText));
      },
      grow: grow,
      maxLines: grow ? null : 1,
    );
  }
}

class LuiColumn extends LuiComponent {
  LuiColumn(super.table)
  : children = table.listValues.map(LuiComponent._parseRec).toList();
  final List<LuiComponent> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget innerWidget(PerformUiAction performAction) {
    final align = enumField('align', CrossAxisAlignment.values);
    final gap = doubField('gap') ?? luaUiGap;
    return Column(
      crossAxisAlignment: align ?? CrossAxisAlignment.start,
      children: children.map((child) => Padding(
          padding: EdgeInsets.only(bottom: child == children.last ? 0 : gap),
          child: child.widget(performAction),
      )).toList(),
    );
  }
}

class LuiRow extends LuiComponent {
  LuiRow(super.table)
  : children = table.listValues.map(LuiComponent._parseRec).toList();
  final List<LuiComponent> children;


  @override
  void setPath(List<int> p) {
    super.setPath(p);
    for (final (idx, child) in children.indexed) {
      child.setPath([...p, idx]);
    }
  }

  @override
  Widget innerWidget(PerformUiAction performAction) {
    final expanded = table['expanded']?.isTruthy == true;
    final align = enumField('align', CrossAxisAlignment.values);
    final gap = doubField('gap') ?? luaUiGap;
    final row = Row(
      crossAxisAlignment: align ?? CrossAxisAlignment.start,
      children: children.map((child) {
          final inside = Padding(
            padding: EdgeInsets.only(right: child == children.last ? 0 : gap),
            child: child.widget(performAction),
          );
          return expanded ? Expanded(child: inside) : inside;
      }).toList()
    );

    if (expanded) return row;
    return Hscroll(child: row);
  }
}

class LuiTable extends LuiComponent {
  LuiTable(super.table)
  : rows = table.listValues.map((row) => (
      table: row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row')) : row,
      // ignore: unnecessary_cast
      cells: (row as LuaTable).listValues.map(LuiComponent._parseRec).toList()
  )).toList();
  final List<({LuaTable table, List<LuiComponent> cells})> rows;


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
  Widget innerWidget(PerformUiAction performAction) => Table(
    border: TableBorder.all(),
    defaultColumnWidth: const IntrinsicColumnWidth(),
    children: rows.map((row) => TableRow(
        children: row.cells.map((cell) => TableCell(
            verticalAlignment: enumField('align', TableCellVerticalAlignment.values, tables: [cell.table, row.table]),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: luaUiPad, vertical: luaUiPad/2),
                child: cell.widget(performAction),
              ),
            )
        )).toList(),
    )).toList()
  );
}

class LuiStack extends LuiComponent {
  LuiStack(super.table) {
    for (final t in table.listValues.whereType<LuaTable>()) {
      if (t['type']?.value == 'line') {
        lines.add(LuiEmpty(t));
      } else {
        children.add(LuiComponent._parseRec(t));
      }
    }
  }
  final List<LuiComponent> children = [];
  final List<LuiEmpty> lines = [];

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

  static Positioned generateChildWidget(LuiComponent child, PerformUiAction onChange, BoxConstraints box) {
    return Positioned(
      left: dimension(child.numField('x'), box.maxWidth),
      top: dimension(child.numField('y'), box.maxHeight),
      width: dimension(child.numField('width'), box.maxWidth),
      height: dimension(child.numField('height'), box.maxHeight),
      child: child.widget(onChange),
    );
  }

  static Positioned generateLineWidget(LuiComponent line, PerformUiAction onChange, BoxConstraints box) {
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
  Widget innerWidget(PerformUiAction performAction) => SizedBox(
    height: doubField('height') ?? 100,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          ...children.map((child) => generateChildWidget(child, performAction, constraints)),
          ...lines.map((child) => generateLineWidget(child, performAction, constraints)),
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
        borderSide: BorderSide(color: Colors.black),
        borderRadius: BorderRadius.all(Radius.circular(luaUiRadius)),
      ),
      contentPadding: EdgeInsets.all(luaUiPad),
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
