import 'package:flutter/material.dart';
import 'package:notes/lua/ensure.dart';
import 'package:notes/lua/object.dart';
import 'package:notes/lua/ui.dart';
import 'package:notes/utils/extensions.dart';


sealed class LuaPromptItem {
  LuaPromptItem(this.table)
  : key = ensureLuaString(table['key'] ?? LuaNil(), 'key')
  , label = ensureLuaString(table['label'] ?? LuaNil(), 'label');
  final LuaTable table;
  final String key;
  final String label;

  static LuaPromptItem parse(LuaTable table) {
    final type = table['type'];
    switch (type?.value) {
      case 'switch': return LuaPromptSwitch(table);
      case 'field': return LuaPromptField(table);
      case 'select': return LuaPromptSelect(table);
      case 'time': return LuaPromptTime(table);
      default: throw 'Invalid prompt field type: $type';
    }
  }

  Widget widget(BuildContext context);
  LuaObject get object;
}

class LuaPromptSwitch extends LuaPromptItem {
  LuaPromptSwitch(super.table);
  @override LuaBoolean object = LuaBoolean(false);
  @override
  Widget widget(BuildContext context) => (
    Switch(value: object.value, onChanged: (v) => object = LuaBoolean(v))
  );
}

class LuaPromptField extends LuaPromptItem {
  LuaPromptField(super.table);
  final controller = TextEditingController(text: '');
  @override LuaString get object => LuaString(controller.text);
  @override
  Widget widget(BuildContext context) => TextField(
    controller: controller,
    maxLines: 1,
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
}

class LuaPromptSelect extends LuaPromptItem {
  LuaPromptSelect(super.table);

  late final options = table.listValues.map((opt) => (
      (opt is LuaString) ? (opt.value, opt.value)
      : (opt is LuaTable) ? (
        ensureLuaString(opt['key'] ?? LuaNil(), 'option.key'),
        ensureLuaString(opt['label'] ?? LuaNil(), 'option.label'),
      )
      : throw 'Invalid select option: $opt'
  )).toList();

  late String selected = options.elementAtOrNull(0)?.$1 ?? (throw 'Empty select menu');
  @override LuaString get object => LuaString(selected);

  @override
  Widget widget(BuildContext context) => DropdownMenu(
    initialSelection: selected,
    onSelected: (val) => selected = val ?? selected,
    dropdownMenuEntries: options.map((opt) => DropdownMenuEntry(value: opt.$1, label: opt.$2)).toList(),
  );
}

class LuaPromptTime extends LuaPromptItem {
  LuaPromptTime(super.table);

  @override LuaObject get object => LuaNil();

  @override
  Widget widget(BuildContext context) => TimePickerDialog(
    initialTime: TimeOfDay.now(),
  );
}


class LuaPromptCallback {
  LuaPromptCallback(this.table)
  : label = ensureLuaString(table['label'] ?? LuaNil(), 'callback.label');
  final LuaTable table;
  final String label;

  Widget widget(BuildContext context, Function() onPress) => ElevatedButton(
    onPressed: onPress,
    child: Text(label),
  );
}


class LuaPrompt extends StatelessWidget {
  LuaPrompt({
      super.key,
      required this.title,
      required this.after,
      required List<LuaTable> options,
      required List<LuaTable> cbs,
  })
  : options = options.map(LuaPromptItem.parse).toList()
  , cbs = cbs.map((t) => LuaPromptCallback(t)).toList();
  final String? title;
  final Function(BuildContext context, LuaTable result, int index) after;
  final List<LuaPromptItem> options;
  final List<LuaPromptCallback> cbs;

  LuaTable collectResults() => LuaTable(Map.fromEntries(
      options.map((opt) => MapEntry(LuaString(opt.key), opt.object))
  ));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: title?.pipe((t) => Text(t)),
    content: SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Expanded(child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, idx) => options[idx].widget(context),
          )),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: cbs.indexed.map((cb) => (
                cb.$2.widget(context, () => after(context, collectResults(), cb.$1))
            )).toList(),
          ),
        ],
      ),
    ),
  );
}
