import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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

  Widget inputWidget(BuildContext context);
  LuaObject get object;

  Widget widget(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 5),
      inputWidget(context),
    ],
  );
}

class LuaPromptSwitch extends LuaPromptItem {
  LuaPromptSwitch(super.table);
  @override LuaBoolean object = LuaBoolean(false);
  @override
  Widget inputWidget(BuildContext context) => (
    StatefulBuilder(
      builder: (context, setState) => Switch(
        value: object.value,
        onChanged: (v) => setState(() => object = LuaBoolean(v)),
      ),
    )
  );
}

class LuaPromptField extends LuaPromptItem {
  LuaPromptField(super.table);
  final controller = TextEditingController(text: '');
  @override LuaString get object => LuaString(controller.text);
  @override
  Widget inputWidget(BuildContext context) => TextField(
    controller: controller,
    maxLines: 1,
    style: const TextStyle(fontSize: luaUiTextSize),
    decoration: const InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black),
        borderRadius: BorderRadius.all(Radius.circular(luaUiRadius)),
      ),
      contentPadding: EdgeInsets.all(luaUiPad),
      isDense: false,
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
  Widget inputWidget(BuildContext context) => DropdownMenu(
    initialSelection: selected,
    onSelected: (val) => selected = val ?? selected,
    dropdownMenuEntries: options.map((opt) => DropdownMenuEntry(value: opt.$1, label: opt.$2)).toList(),
  );
}

class LuaPromptTime extends LuaPromptItem {
  LuaPromptTime(super.table);

  DateTime dateTime = DateTime.now();
  @override LuaObject get object => LuaString(timeStamp());

  static const List<String> daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String timeStamp() => (
    "<${dateTime.year}"
    "-${dateTime.month.toString().padLeft(2, '0')}"
    "-${dateTime.day.toString().padLeft(2, '0')}"
    " ${daysOfWeek[dateTime.weekday - 1]}"
    " ${dateTime.hour.toString().padLeft(2, '0')}"
    ":${dateTime.minute.toString().padLeft(2, '0')}"
    ">"
  );

  @override
  Widget inputWidget(BuildContext context) => StatefulBuilder(
    builder: (context, setState) => ElevatedButton(
      onPressed: () async {
        final day = await showDatePicker(
          context: context,
          firstDate: DateTime.fromMillisecondsSinceEpoch(0),
          lastDate: DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch*2),
        );
        if (day == null) return;

        final time = await showTimePicker(
          // ignore: use_build_context_synchronously
          context: context,
          initialTime: TimeOfDay.fromDateTime(dateTime),
        );
        if (time == null) return;

        setState(() => dateTime = day.add(Duration(hours: time.hour, minutes: time.minute)));
      },
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(luaUiRadius)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        // backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(width: 1, color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.clock),
          const SizedBox(width: 10),
          Text(timeStamp()),
        ],
      ),
    ),
  );
}


class LuaPromptCallback {
  LuaPromptCallback(this.table)
  : label = ensureLuaString(table['label'] ?? LuaNil(), 'callback.label');
  final LuaTable table;
  final String label;

  Widget widget(BuildContext context, Function() onPress) => ElevatedButton(
    onPressed: onPress,
    style: ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(luaUiRadius)),
      padding: const EdgeInsets.all(17)
    ),
    child: Text(label, style: const TextStyle(fontSize: 17)),
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
    title: title?.pipe((t) => Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(width: 0.5))),
        child: Center(child: Text(t, textScaler: const TextScaler.linear(1.2))),
    )),
    content: SizedBox(
      width: MediaQuery.of(context).size.width * 0.65,
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Expanded(child: ListView.separated(
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemCount: options.length,
              itemBuilder: (context, idx) => options[idx].widget(context),
          )),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: cbs.indexed.map((cb) => (
                cb.$2.widget(context, () => after(context, collectResults(), cb.$1))
            )).toList().reversed.toList(),
          ),
        ],
      ),
    ),
  );
}
