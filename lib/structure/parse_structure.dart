import 'package:notes/structure/code.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


(int, Match)? _lineMatch(Iterable<String> lines, RegExp regexp) => (
  lines.indexed
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
    final propsEnd = _lineMatch(lines.skip(1), propsEndRegexp)?.$1;
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
  (int, Match)? nextHeading = _lineMatch(lines.skip(contentStart), headingRegexp);
  final contentEnd = nextHeading?.$1 ?? lines.length;

  // Parse the content
  final elements = <StructureElement>[];
  for (int line = contentStart; line < contentEnd;) {
    final specialElement = (
      StructureTable.maybeParse(lines, line)
      ?? StructureCode.maybeParse(lines, line)
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
  while (nextHeading != null) {
    final (prevHeadingLine, prevHeadingMatch) = nextHeading;

    nextHeading = _lineMatch(lines.skip(prevHeadingLine+1), headingRegexp);
    final prevHeadingLines = lines.sublist(prevHeadingLine+1, nextHeading?.$1 ?? lines.length);
    final headingContent = parseStructure(prevHeadingLines, level: level+1);
    headings.add((prevHeadingMatch.group(1)!, headingContent));
  }

  return NoteStructure(props: props, content: elements, headings: headings);
}
