import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/editor/notes_handler.dart';

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
        useMaterial3: true,
      ),
      // Having this as a builder means that overlays and popups will also be affected
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
        child: child ?? Container(),
      ),
      home: NoteHandler(directory: Directory('/home/benzanol/Documents/repo')),
    );
  }
}
