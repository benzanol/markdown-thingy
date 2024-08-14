import 'package:flutter/material.dart';
import 'package:notes/sections/markdown_section.dart';
import 'package:notes/sections/table_section.dart';


const double hPadding = 16;
const double vPadding = 8;


List<NoteSection> _generateSections(String text, {Function()? onUpdate, bool raw = false}) {
  final sections = <NoteSection>[];

  if (raw) {
    sections.add(MarkdownSection(text));

  } else {
    final lines = text.split('\n');

    int textStart = 0;
    for (int line = 0; line < lines.length; line++) {
      final special = _specialSection(lines, line);
      if (special == null) continue;

      if (textStart < line) {
        sections.add(MarkdownSection(lines.getRange(textStart, line).join('\n')));
      }
      sections.add(special.$1);
      line = special.$2;
      textStart = line;
    }
    // Add the remaining lines, if any
    if (textStart < lines.length) {
      sections.add(MarkdownSection(lines.skip(textStart).join('\n')));
    }
  }

  // Add the on update, if it exists
  if (onUpdate != null) {
    for (final sec in sections) {
      sec.onUpdate = onUpdate;
    }
  }

  return sections;
}

// Returns the section, and the next line after the section
(NoteSection, int)? _specialSection(List<String> lines, int line) {
  return TableSection.maybeParse(lines, line);
}



class NoteEditor extends StatelessWidget {
  NoteEditor({super.key, required this.init, this.onUpdate, this.raw = false});

  final String init;
  final Function(NoteEditor)? onUpdate;
  final bool raw;
  late final List<NoteSection> sections = _generateSections(init, onUpdate: updateParent, raw: raw);

  void updateParent() => onUpdate?.call(this);

  String getText() => sections.map((s) => s.getText()).join('\n');

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    return Scrollbar(
      thickness: 5,
      thumbVisibility: true,
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        itemCount: sections.length,
        itemBuilder: (context, idx) => sections[idx].widget(context),
      ),
    );
  }
}

abstract class NoteSection {
  NoteSection();
  Function()? onUpdate;

  String getText();
  Widget widget(BuildContext context);
}
