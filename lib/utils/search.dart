import 'package:flutter/material.dart';

extension DedupExtension<T> on Iterable<T> {
  Iterable<T> dedup() sync* {
    var seen = <T>{};
    for (var element in this) {
      if (seen.add(element)) {
        yield element;
      }
    }
  }
}

class SearchMenu extends StatefulWidget {
  const SearchMenu({
      super.key,
      required this.options,
      required this.onSelect,
      this.count = 10,
      this.initial,
  });
  final List<String> options;
  final Function(String) onSelect;
  final int count;
  final List<String>? initial;

  @override
  State<SearchMenu> createState() => _SearchMenuState();
}

class _SearchMenuState extends State<SearchMenu> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final search = controller.text.split(' ').where((seg) => seg.isNotEmpty).toList();
    final cands = search.isEmpty ? (widget.initial ?? widget.options) : widget.options;
    final narrowed = cands.where((cand) => search.every((seg) => cand.contains(seg))).dedup().toList();

    final fieldWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        autofocus: true,
        controller: controller,
        onChanged: (val) => setState(() {}),
        style: const TextStyle(fontSize: 22),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );

    final optionsWidget = Expanded(
      child: ListView.builder(
        itemCount: narrowed.length,
        itemBuilder: (context, idx) => PopupMenuItem(
          onTap: () => widget.onSelect(narrowed[idx]),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(narrowed[idx], style: const TextStyle(fontSize: 18)),
        ),
      ),
    );

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      contentPadding: const EdgeInsets.all(0),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [fieldWidget, optionsWidget],
        ),
      ),
    );
  }
}
