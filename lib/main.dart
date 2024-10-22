import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:notes/drawer/git.dart';
import 'package:notes/editor/extensions.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/editor/repo_file_manager.dart';
import 'package:notes/utils/future.dart';


void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorMessage = details.exceptionAsString();
    final stackTrace = details.stack.toString().split('\n').take(10).join('\n');

    // ANSI escape code for red text
    const String redText = '\x1B[31m';
    const String resetText = '\x1B[0m';

    // Print the stack trace first and then the error message at the bottom
    // debugPrint('$stackTrace\n\n${redText}ERROR MESSAGE: $errorMessage$resetText');
    debugPrint('$stackTrace\n\n${redText}ERROR MESSAGE: $errorMessage$resetText');
  };

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final root = concatPaths(Platform.environment['HOME']!, 'Documents/repo');
    final handler = NoteHandler(root: Directory(root));
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'IbmPlexSans',
        useMaterial3: true,
      ),
      // Having this as a builder means that overlays and popups will also be wrapped
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child ?? Container()
      ),

      home: FutureWaiter(
        future: Future.wait([
            initializeHandlerExtensions(handler),
            GithubRepo.fromStorage().then((repo) => handler.git = repo),
        ]),
        waiting: const Scaffold(
          body: SpinKitChasingDots(color: Colors.black)
        ),
        onSuccess: (context, value) {
          return NoteHandlerWidget(handler: handler);
        },
      ),
    );
  }
}
