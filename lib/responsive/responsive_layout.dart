import 'package:flutter/material.dart';

/// [ResponsiveLayout] renders different widgets based on screen width Media Queries
/// (Mobile: < 600, Tablet: 600-1024, Desktop: >= 1024).
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Standard Breakpoint Constants (in pixels)
  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletMax) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= mobileMax) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
