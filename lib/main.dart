import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/editor/notes_handler.dart';


Directory repoRootDirectory = Directory('/home/benzanol/Documents/repo');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'IbmPlexSans',
        useMaterial3: true,
      ),
      // Having this as a builder means that overlays and popups will also be affected
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child ?? Container()
      ),
      home: NoteHandler(directory: repoRootDirectory),
    );
  }
}
