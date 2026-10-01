import 'package:flutter/material.dart';
import 'responsive_size.dart';

/// [ResponsiveInit] automatically initializes screen scaling for child widgets
/// so that `.w`, `.h`, `.sp`, `.r` and pixel sizes scale accurately across all screens.
class ResponsiveInit extends StatelessWidget {
  final Widget child;
  final double designWidth;
  final double designHeight;

  const ResponsiveInit({
    super.key,
    required this.child,
    this.designWidth = 375,
    this.designHeight = 812,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        ResponsiveSize.init(
          context,
          designWidth: designWidth,
          designHeight: designHeight,
        );
        return child;
      },
    );
  }
}
