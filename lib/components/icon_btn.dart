import 'package:flutter/material.dart';

class IconBtn extends StatelessWidget {
  const IconBtn({
      super.key,
      required this.icon,
      this.onPressed,
      this.radius = 0,
      this.scale = 1,
  });
  final IconData icon;
  final Function()? onPressed;
  final double radius;
  final double scale;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    onPressed: onPressed,
    constraints: const BoxConstraints(),
    padding: EdgeInsets.all(radius),
    iconSize: scale * 24,
  );
}
