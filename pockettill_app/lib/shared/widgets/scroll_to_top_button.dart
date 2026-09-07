import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small "scroll to top" button that fades in once [controller] has
/// scrolled past [showAfter], and animates the list back to the top when
/// tapped. Position it as a child of a [Stack] wrapping the scrollable
/// content (e.g. `Stack(children: [myListView, const ScrollToTopButton(...)])`).
class ScrollToTopButton extends StatefulWidget {
  const ScrollToTopButton({
    super.key,
    required this.controller,
    this.showAfter = 400,
    this.bottom = 16,
    this.right = 16,
  });

  final ScrollController controller;
  final double showAfter;
  final double bottom;
  final double right;

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final show = widget.controller.offset > widget.showAfter;
    if (show != _visible) setState(() => _visible = show);
  }

  void _scrollToTop() {
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: widget.right,
      bottom: widget.bottom,
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: _scrollToTop,
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.primary,
            elevation: 3,
            child: const Icon(Icons.keyboard_arrow_up),
          ),
        ),
      ),
    );
  }
}
