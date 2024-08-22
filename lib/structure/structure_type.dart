abstract class StructureType {
  const StructureType();
  static StructureType? fromFile(String path) => (
    path.endsWith('.md') ? const MarkdownStructureType()
    : path.endsWith('.org') ? const OrgStructureType()
    : null
  );

  String get headingPrefixChar;

  String get beginProps;
  String get endProps;

  String get beginCode;
  String get endCode;

  String get beginLens;
  String get endLens;


  RegExp headingRegexp(int level) => RegExp('^${RegExp.escape(headingPrefixChar) * level} (.+)\$');

  RegExp get beginPropsRegexp => RegExp('^${RegExp.escape(beginProps)}\$');
  RegExp get endPropsRegexp => RegExp('^${RegExp.escape(endProps)}\$');

  RegExp get beginCodeRegexp => RegExp('^${RegExp.escape(beginCode)}([a-zA-Z0-9-_]+)\$');
  RegExp get endCodeRegexp => RegExp('^${RegExp.escape(endCode)}\$');

  RegExp get beginLensRegexp => RegExp('^${RegExp.escape(beginLens)}([a-zA-Z0-9]+)/([a-zA-Z0-9]+)\$');
  RegExp get endLensRegexp => RegExp('^${RegExp.escape(endLens)}\$');
}

class MarkdownStructureType extends StructureType {
  const MarkdownStructureType();

  @override String get headingPrefixChar => '#';

  @override String get beginProps => '---';
  @override String get endProps => '---';

  @override String get beginCode => '```';
  @override String get endCode => '```';

  @override String get beginLens => '```';
  @override String get endLens => '```';
}

class OrgStructureType extends StructureType {
  const OrgStructureType();

  @override String get headingPrefixChar => '*';

  @override String get beginProps => ':PROPERTIES:';
  @override String get endProps => ':END:';

  @override String get beginCode => '#+begin_src ';
  @override String get endCode => '#+end_src';

  @override String get beginLens => '#+begin_lens ';
  @override String get endLens => '#+end_lens';
}
