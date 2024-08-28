import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';


class ForegroundSvg extends StatelessWidget {
  const ForegroundSvg({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) => SvgPicture.file(
    file,
    fit: BoxFit.fitHeight,
    colorFilter: ColorFilter.mode(
      Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}
