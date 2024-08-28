import 'package:flutter/material.dart';


class WithColor extends StatelessWidget {
  const WithColor({super.key, required this.child, this.color, this.scheme});

  final Widget child;
  final Color? color;
  final Color Function(ColorScheme cs)? scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = DefaultTextStyle.of(context);
    final c = color ?? scheme?.call(theme.colorScheme) ?? theme.colorScheme.onSurface;

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(onSurface: c),
        iconTheme: theme.iconTheme.copyWith(color: c),
      ),
      child: DefaultTextStyle(
        style: textStyle.style.copyWith(color: c),
        child: child,
      ),
    );
  }
}
