import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:notes/extensions/lua_object.dart';


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
    if (obj is! LuaTable) throw InvalidLuaUiError('Ui must be a table: $obj');

    final type = obj.value[LuaString('type')];
    if (type is! LuaString) throw InvalidLuaUiError('Ui table must have a type property: $obj');

    switch (type.value) {
      case 'label': return LuaLabelUi(obj.listValues.firstOrNull?.display() ?? '');
      case 'field': return LuaTextFieldUi(obj.listValues.firstOrNull?.display() ?? '');
      case 'button': return LuaButtonUi(
        obj.listValues.firstOrNull?.display()
        ?? (throw InvalidLuaUiError('Button must have a label: $obj'))
      );

      case 'column': return LuaColumnUi(obj.listValues.map(LuaUi._parse).toList());
      case 'row': return LuaRowUi(obj.listValues.map(LuaUi._parse).toList());
      case 'table': return LuaTableUi(
        obj.listValues.map((row) => (
            row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row'))
            : row.listValues.map(LuaUi._parse).toList()
        )).toList()
      );

      default: throw InvalidLuaUiError('Invalid ui type: ${type.value}');
    }
  }
}

class LuaLabelUi extends LuaUi {
  final String text;
  LuaLabelUi(this.text);

  @override
  Widget widget(onChange) => Text(text);
}

class LuaButtonUi extends LuaUi {
  LuaButtonUi(this.label);
  String label;

  @override
  void performChange(LuaState lua) {
    lua.getField(-1, 'onPress');
    // Call the function
    if (lua.isFunction(-1)) {
      lua.call(0, 0);
    }
  }

  @override
  Widget widget(onChange) => ElevatedButton(
    onPressed: () => onChange(this),
    child: Text(label),
  );
}

class LuaTextFieldUi extends LuaUi {
  LuaTextFieldUi(String init) : controller = TextEditingController(text: init);
  final TextEditingController controller;

  @override
  void performChange(LuaState lua) {
    lua.getField(-1, 'onChange');
    // Call the function with the string argument
    if (lua.isFunction(-1)) {
      lua.pushString(controller.text);
      lua.call(1, 0);
    }
  }

  @override
  Widget widget(onChange) => TextField(
    controller: controller,
    onChanged: (_) => onChange(this),
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
    children: children.map((child) => child.widget(onChange)).toList(),
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
    children: children.map((child) => child.widget(onChange)).toList()
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
    children: rows.map((row) => TableRow(
        children: row.map((cell) => cell.widget(onChange)).toList(),
    )).toList()
  );
}
