import 'package:flutter/material.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/extensions/load_extensions.dart';


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
  LensExtension({required this.ext, required this.name, required this.actions});
  final String ext;
  final String name;
  final List<EditorAction<GlobalKey>> actions;

  List<String> get lensFields => [ext, extsLensesField, name];
}
