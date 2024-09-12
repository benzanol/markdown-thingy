import 'package:flutter/material.dart';

class IconBtn extends StatelessWidget {
  const IconBtn({
      super.key,
      required this.icon,
      this.onPressed,
      this.padding = 0,
      this.scale = 1,

      this.color,
      this.bgColor,
      this.borderColor,
  });
  final IconData icon;
  final Function()? onPressed;
  final double padding;
  final double scale;

  final Color? color;
  final Color? bgColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    color: color,
    onPressed: onPressed,
    constraints: const BoxConstraints(),
    padding: EdgeInsets.all(padding),
    iconSize: scale * 24,
    style: IconButton.styleFrom(
      backgroundColor: bgColor,
      shape: borderColor == null ? null : CircleBorder(
        side: BorderSide(width: 1.5, color: borderColor!),
      ),
    ),
  );
}
