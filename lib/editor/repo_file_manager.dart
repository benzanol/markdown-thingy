import 'dart:async';
import 'dart:io';


enum FileType {
  file(), directory();
  const FileType();

  static FileType of(FileSystemEntity entity) => (
    entity is File ? FileType.file
    : entity is Directory ? FileType.directory
    : throw 'Invalid file type: $entity'
  );

  bool get isFile => this == FileType.file;
  bool get isDir => this == FileType.directory;
}

class RepoFileManager {
  RepoFileManager(Directory root) : _root = root.absolute;
  final Directory _root;
  Directory filesystemRepoPath() => _root;

  String _resolveAbs(String path) {
    if (path.startsWith('/')) path = path.substring(1);
    if (path.startsWith('~/')) path = path.substring(2);
    final absolute = _root.uri.resolve(path).path;
    if (absolute.startsWith(_root.path)) return absolute;
    throw 'Path outside of repo: $path';
  }

  FileSystemEntity _resolveEntity(String path, FileType ft) {
    final abs = _resolveAbs(path);
    switch (ft) {
      case FileType.file: return File(abs);
      case FileType.directory: return Directory(abs);
    }
  }


  FileType? exists(String path) {
    for (final type in FileType.values) {
      if (_resolveEntity(path, type).existsSync()) return type;
    }
    return null;
  }
  bool existsFile(String path) => exists(path) == FileType.file;
  bool existsDir(String path) => exists(path) == FileType.directory;

  FileType ensureExists(String path) => exists(path) ?? (throw '$path does not exist');
  void ensureFile(String path) => ensureExists(path).isFile ? null : throw 'File $path does not exist';
  void ensureDir(String path) => ensureExists(path).isDir ? null : throw 'Directory $path does not exist';


  void createOrErr(String path, {FileType ft = FileType.file}) {
    if (exists(path) != null) throw 'File $path already exists';

    final abs = _resolveAbs(path);
    switch (ft) {
      case FileType.file: return File(abs).createSync();
      case FileType.directory: return Directory(abs).createSync();
    }
  }

  void renameOrErr(String path, String newName) {
    final ft = ensureExists(path);
    final newPath = concatPaths(fileParent(path), newName);
    _resolveEntity(path, ft).rename(_resolveAbs(newPath));
  }

  void deleteOrErr(String path) {
    final type = ensureExists(path);
    _resolveEntity(path, type).deleteSync(recursive: true);
  }


  String readOrErr(String file) {
    ensureFile(file);
    return File(_resolveAbs(file)).readAsStringSync();
  }

  void writeOrErr(String file, String contents) {
    ensureFile(file);
    File(_resolveAbs(file)).writeAsStringSync(contents);
  }


  List<(String, FileType)> listOrErr(String path) {
    ensureDir(path);
    return Directory(_resolveAbs(path)).listSync()
    .map((entity) => (fileName(entity.path), FileType.of(entity)))
    .toList();
  }

  List<String> listDirsOrErr(String path) {
    return listOrErr(path)
    .where((tup) => tup.$2.isDir)
    .map((tup) => tup.$1)
    .toList();
  }

  List<String> listFilesOrErr(String path) {
    return listOrErr(path)
    .where((tup) => tup.$2.isFile)
    .map((tup) => tup.$1)
    .toList();
  }


  StreamSubscription<FileSystemEvent> dirWatcher(String dir, Function() onUpdate) {
    ensureDir(dir);
    return Directory(_resolveAbs(dir)).watch().listen((event) => onUpdate);
  }
}


String fileName(String path) => File(path).uri.pathSegments.lastWhere((seg) => seg.isNotEmpty);
String fileParent(String path) => path.substring(0, path.length - fileName(path).length);

String concatPaths(String parent, String child) {
  if (child == '~') return '/';
  if (child.startsWith('~/')) child = child.substring(1);
  if (child.startsWith('/')) return child;
  return parent.endsWith('/') ? '$parent$child' : '$parent/$child';
}
