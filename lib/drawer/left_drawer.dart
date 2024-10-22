import 'package:flutter/material.dart';


class LeftDrawer extends StatelessWidget {
  const LeftDrawer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const ContinuousRectangleBorder(),
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}
