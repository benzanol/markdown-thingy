import 'package:flutter/material.dart';


class WithColor extends StatelessWidget {
  const WithColor({super.key, required this.child, this.color, this.scheme});

  final Widget child;
  final Color? color;
  final Color Function(ColorScheme cs)? scheme;

  @override
  Widget build(BuildContext context) {
    if (color == null && scheme == null) return child;

    final theme = Theme.of(context).copyWith();
    final c = color ?? scheme!(theme.colorScheme);

    return Theme(
      data: theme.copyWith(colorScheme: theme.colorScheme.copyWith(onSurface: c)),
      child: DefaultTextStyle(
        style: TextStyle(color: c),
        child: child,
      ),
    );
  }
}
