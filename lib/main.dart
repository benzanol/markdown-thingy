import 'package:flutter/material.dart';
import 'package:notes/editor/note_handler.dart';


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
      home: const NoteHandler(),
    );
  }
}
