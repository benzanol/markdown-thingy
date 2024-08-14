import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/drawer/file_browser.dart';


class LeftDrawer extends StatelessWidget {
  const LeftDrawer({super.key, required this.dir, required this.openFile});
  final Directory dir;
  final Function(File) openFile;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const ContinuousRectangleBorder(),
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(10),
        child: FileBrowserDirectory(dir: dir, openFile: openFile),
      ),
    );
  }
}
