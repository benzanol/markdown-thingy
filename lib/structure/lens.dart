import 'package:flutter/material.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/structure/structure.dart';


final RegExp lensStartRegexp = RegExp(r'^#\+begin_lens ([a-zA-Z0-9]+)/([a-zA-Z0-9]+)$');
final RegExp lensEndRegexp = RegExp(r'^#\+end_lens$');


class StructureLens extends StructureElement {
  StructureLens.generate({required this.lens, required this.init})
  : _instanceId = lens.generateState(init);

  final LensExtension lens;
  final String init;
  final int _instanceId;

  static (StructureLens, int)? maybeParse(List<String> lines, int line) {
    final startMatch = lensStartRegexp.firstMatch(lines[line]);
    if (startMatch == null) return null;

    final endLine = lines.indexed.where((tup) => lensEndRegexp.hasMatch(tup.$2)).firstOrNull;
    if (endLine == null) return null;

    final lens = getLens(startMatch.group(1)!, startMatch.group(2)!);
    if (lens == null) return null;

    final content = lines.getRange(line + 1, endLine.$1).join('\n');
    final nextLine = endLine.$1 + 1;
    try {
      return (StructureLens.generate(lens: lens, init: content), nextLine);
    } catch (e) {
      return (StructureFailedLens(lens: lens, init: content, error: '$e'), nextLine);
    }
  }

  @override
  String toText() {
    String content;
    try {
      content = lens.generateText(_instanceId);
    } catch (e) {
      content = init;
    }
    return '#+begin_lens ${lens.dir}/${lens.name}\n$content\n#+end_lens';
  }

  @override
  Widget widget(Function() onUpdate) {
    try {
      return lens.generateUi(_instanceId).widget();
    } catch (e) {
      return Text('$e', style: const TextStyle(color: Colors.red));
    }
  }
}

class StructureFailedLens implements StructureLens {
  StructureFailedLens({required this.lens, required this.init, required this.error});
  @override final LensExtension lens;
  @override int get _instanceId => 0;
  @override final String init;
  final String error;

  @override
  String toText() => init;

  @override
  Widget widget(Function() onUpdate) => (
    Text(error, style: const TextStyle(color: Colors.red))
  );
}
