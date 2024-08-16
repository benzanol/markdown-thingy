import 'package:flutter/material.dart';
import 'package:notes/extensions/lua_object.dart';


class InvalidLuaUiError extends Error {
  InvalidLuaUiError(this.message);
  final String message;
  @override String toString() => message;
}


abstract class LuaUi {
  Widget widget();

  static LuaUi parse(LuaObject obj) {
    if (obj is! LuaTable) throw InvalidLuaUiError('Ui must be a table: $obj');

    final type = obj.value[LuaString('type')];
    if (type is! LuaString) throw InvalidLuaUiError('Ui table must have a type property: $obj');

    switch (type.value) {
      case 'label': return LuaLabel(obj.listValues.firstOrNull?.toString() ?? '');
      case 'field': return LuaTextField(obj.listValues.firstOrNull?.toString() ?? '');
      case 'column': return LuaColumn(obj.listValues.map(LuaUi.parse).toList());
      case 'row': return LuaRow(obj.listValues.map(LuaUi.parse).toList());
      case 'table': return LuaTableUi(
        obj.listValues.map((row) => (
            row is! LuaTable ? (throw InvalidLuaUiError('Invalid table row: $row'))
            : row.listValues.map(LuaUi.parse).toList()
        )).toList()
      );
      default: throw InvalidLuaUiError('Invalid ui type: ${type.value}');
    }
  }
}

class LuaLabel extends LuaUi {
  final String text;
  LuaLabel(this.text);

  @override
  Widget widget() => Text(text);
}

class LuaTextField extends LuaUi {
  final String initialText;
  LuaTextField(this.initialText);

  @override
  Widget widget() => TextField(
    controller: TextEditingController(text: initialText),
  );
}

class LuaColumn extends LuaUi {
  LuaColumn(this.children);
  final List<LuaUi> children;

  @override
  Widget widget() => Column(children: children.map((child) => child.widget()).toList());
}

class LuaRow extends LuaUi {
  LuaRow(this.children);
  final List<LuaUi> children;

  @override
  Widget widget() => Row(children: children.map((child) => child.widget()).toList());
}

class LuaTableUi extends LuaUi {
  LuaTableUi(this.rows);
  final List<List<LuaUi>> rows;

  @override
  Widget widget() => Table(
    children: rows.map((row) => TableRow(
        children: row.map((cell) => cell.widget()).toList(),
    )).toList()
  );
}
