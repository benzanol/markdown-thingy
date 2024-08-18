import 'package:notes/structure/code.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


(int, Match)? _lineMatch(int start, Iterable<String> lines, RegExp regexp) => (
  lines.indexed
  .skip(start)
  .map((line) {
      final match = regexp.matchAsPrefix(line.$2);
      return match == null ? null : (line.$1, match);
  })
  .where((m) => m != null)
  .firstOrNull
);

NoteStructure parseStructure(List<String> lines, {int level = 0}) {
  final headingRegexp = RegExp('^${"#" * (1+level)} (.+)\$');
  final propsStartRegexp = RegExp(r'^---$');
  final propsEndRegexp = RegExp(r'^---$');

  // Figure out if there is a property section
  int contentStart = 0;
  Map<String, String> props = {};
  if (lines.isNotEmpty && propsStartRegexp.hasMatch(lines.first)) {
    final propsEnd = _lineMatch(1, lines, propsEndRegexp)?.$1;
    if (propsEnd != null) {
      contentStart = propsEnd + 1;

      // Parse the property lines
      props = Map.fromEntries(
        lines.getRange(1, propsEnd - 1).expand((line) {
            final index = line.indexOf(':');
            if (index == -1) return [];
            return [MapEntry(line.substring(0, index), line.substring(index + 1))];
        })
      );
    }
  }

  // Find the first heading
  (int, Match)? nextHead = _lineMatch(contentStart, lines, headingRegexp);
  final contentEnd = nextHead?.$1 ?? lines.length;

  // Parse the content
  final elements = <StructureElement>[];
  for (int line = contentStart; line < contentEnd;) {
    final specialElement = (
      StructureTable.maybeParse(lines, line)
      ?? StructureCode.maybeParse(lines, line)
      ?? StructureLens.maybeParse(lines, line)
    );

    if (specialElement == null) {
      final last = elements.lastOrNull;
      if (last is StructureText) {
        last.lines.add(lines[line]);
      } else {
        elements.add(StructureText([lines[line]]));
      }
      line++;
    } else {
      elements.add(specialElement.$1);
      line = specialElement.$2;
    }
  }

  // Parse each heading section
  final headings = <(String, NoteStructure)>[];
  while (nextHead != null) {
    final (prevHeadLine, prevHeadMatch) = nextHead;


    nextHead = _lineMatch(prevHeadLine+1, lines, headingRegexp);
    final prevHeadLines = lines.sublist(prevHeadLine+1, nextHead?.$1 ?? lines.length);
    final prevHeadContent = parseStructure(prevHeadLines, level: level+1);
    headings.add((prevHeadMatch.group(1)!, prevHeadContent));
  }

  return NoteStructure(props: props, content: elements, headings: headings);
}
