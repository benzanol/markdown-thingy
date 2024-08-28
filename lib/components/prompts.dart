import 'package:flutter/material.dart';


Future<String?> promptString(BuildContext context, String question) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: question),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}

Future<bool> promptConfirmation(BuildContext context, String question) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  ).then((confirmed) => confirmed ?? false);
}
