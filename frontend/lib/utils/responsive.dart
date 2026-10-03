import 'dart:math' as math;

import 'package:flutter/material.dart';

class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1000;
}

bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= Breakpoints.tablet;
bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= Breakpoints.desktop;

/// Centers content, caps its width, and adds page padding that grows on large screens.
class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = isTablet(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: wide ? 28 : 16),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Scrollable, centered, optionally pull-to-refresh page body.
class ScrollPage extends StatelessWidget {
  const ScrollPage({super.key, required this.child, this.maxWidth = 1100, this.onRefresh});

  final Widget child;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: PageContainer(maxWidth: maxWidth, child: child),
    );
    if (onRefresh != null) content = RefreshIndicator(onRefresh: onRefresh!, child: content);
    return content;
  }
}

/// Lays children out in as many equal columns as fit, given a minimum item width.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 240, this.gap = 16});

  final List<Widget> children;
  final double minItemWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = math.max(1, ((w + gap) / (minItemWidth + gap)).floor());
      final itemWidth = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: itemWidth, child: c)],
      );
    });
  }
}
