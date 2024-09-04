import 'package:flutter/material.dart';
import 'package:notes/components/icon_btn.dart';


class FoldButton extends StatelessWidget {
  const FoldButton({super.key, required this.isFolded, this.setFolded});
  final bool isFolded;
  final Function(bool)? setFolded;

  @override
  Widget build(BuildContext context) => IconBtn(
    icon: isFolded ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
    radius: 5,
    onPressed: () => setFolded?.call(!isFolded),
  );
}
