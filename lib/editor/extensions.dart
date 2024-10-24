import 'package:notes/editor/note_handler.dart';
import 'package:notes/structure/structure_parser.dart';


const String extDirectory = 'extensions';
const List<String> extIndexFileNames = ['index.md', 'index.org', 'index.lua'];
const String extsVariable = '*extensions*';

const String extsReturnField = 'value';
const String extsLensesField = 'lenses';
const String extsButtonsField = 'buttons';


String? extensionIndexFile(NoteHandler handler, String ext) {
  final files = handler.fs.listFilesOrErr('$extDirectory/$ext');
  return extIndexFileNames.where((name) => files.contains(name)).firstOrNull;
}

String? extensionOfFile(NoteHandler handler, String path) {
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.length < 2) return null;
  if (segs[0] != extDirectory) return null;
  return extensionIndexFile(handler, segs[1]);
}


Future<void> initializeHandlerExtensions(NoteHandler handler) async {
  await Future.delayed(const Duration(milliseconds: 1));

  if (!handler.fs.existsDir(extDirectory)) return;
  for (final ext in handler.fs.listDirsOrErr(extDirectory)) {
    final indexFile = extensionIndexFile(handler, ext);
    if (indexFile == null) return;

    final content = handler.fs.readOrErr('$extDirectory/$ext/$indexFile');
    final struct = StructureParser.fromFile(indexFile)!.parse(content);

    handler.lua.executeExtensionCode(ext, struct.getLuaCode());
  }
}


const String toStateField = 'parse';
const String toTextField = 'format';
const String toUiField = 'render';
const String actionsField = 'actions';

const String instancesVariable = '*instances*';
const String lensesStateField = 'state';
const String lensesUiField = 'ui';


final Set<LensExtension> lensTypes = {};
LensExtension? getLens(String ext, String name) => (
  lensTypes.where((l) => l.ext == ext && l.name == name).firstOrNull
);


class LensExtension {
  LensExtension({required this.ext, required this.name});
  final String ext;
  final String name;
  // final List<EditorAction<GlobalKey>> actions;

  List<String> get lensFields => [ext, extsLensesField, name];
}
