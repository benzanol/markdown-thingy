import 'package:flutter/material.dart';
import 'package:notes/components/with_color.dart';


class Hscroll extends StatefulWidget {
  const Hscroll({super.key, required this.child, this.center});
  final Widget child;
  final double? center;

  @override
  State<Hscroll> createState() => _HscrollState();
}

class _HscrollState extends State<Hscroll> {
  final GlobalKey _key = GlobalKey();
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _updateScroll();
  }

  void _updateScroll() {
    final center = widget.center;
    if (center == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
        final renderBox = _key.currentContext?.findRenderObject() as RenderBox;
        final widgetWidth = renderBox.size.width;
        final maxScroll = _controller.position.maxScrollExtent;

        _controller.animateTo(
          (center - widgetWidth/2).clamp(0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateScroll();

    // Set the scrollbar color to the secondary color to achieve consistency
    return WithColor(
      color: Theme.of(context).colorScheme.secondary,
      child: Scrollbar(
        thickness: 5,
        thumbVisibility: true,
        controller: _controller,
        child: SingleChildScrollView(
          key: _key,
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: WithColor(
              color: Theme.of(context).colorScheme.onSurface,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
