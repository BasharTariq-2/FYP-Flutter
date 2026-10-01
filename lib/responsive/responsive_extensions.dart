import 'package:flutter/material.dart';
import 'responsive_size.dart';

/// Extension on [num] to easily write responsive pixel & percentage values:
/// Pixel Examples: `16.w`, `20.h`, `14.sp`, `12.r`
/// Percentage Examples: `50.wp` (50% screen width), `30.hp` (30% screen height), `4.spPercent` (4% text font size)
extension ResponsiveNumExtension on num {
  // --- Fixed Design Pixel Scaling ---
  /// Responsive width based on design pixels
  double get w => ResponsiveSize.setWidth(toDouble());

  /// Responsive height based on design pixels
  double get h => ResponsiveSize.setHeight(toDouble());

  /// Responsive Scalable Pixels for font size
  double get sp => ResponsiveSize.setSp(toDouble());

  /// Responsive Radius for BorderRadius, Icons, Avatars
  double get r => ResponsiveSize.setRadius(toDouble());

  /// Helper widget for horizontal spacing: `16.horizontalSpace`
  Widget get horizontalSpace => SizedBox(width: w);

  /// Helper widget for vertical spacing: `20.verticalSpace`
  Widget get verticalSpace => SizedBox(height: h);

  // --- Percentage Media Query Scaling (% of Screen) ---
  /// Screen Width Percentage (e.g., `50.wp` = 50% of screen width)
  double get wp => ResponsiveSize.wp(toDouble());
  double get wPercent => wp;

  /// Screen Height Percentage (e.g., `30.hp` = 30% of screen height)
  double get hp => ResponsiveSize.hp(toDouble());
  double get hPercent => hp;

  /// Scalable Font Percentage based on screen width (e.g., `4.5.spPercent`)
  double get spPercent => ResponsiveSize.spPercent(toDouble());

  /// Radius Percentage based on minimum screen dimension (e.g., `5.rp`)
  double get rp => ResponsiveSize.radiusPercent(toDouble());
  double get rPercent => rp;
}

/// Extension on [BuildContext] for Media Query properties and responsive helpers
extension BuildContextResponsiveExtension on BuildContext {
  /// Raw MediaQueryData
  MediaQueryData get mq => MediaQuery.of(this);

  /// Screen dimensions
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Safe area paddings / status bar / bottom inset
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);
  double get paddingTop => screenPadding.top;
  double get paddingBottom => screenPadding.bottom;
  double get paddingLeft => screenPadding.left;
  double get paddingRight => screenPadding.right;

  /// Screen Orientation
  Orientation get orientation => mq.orientation;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;

  /// Device Pixel Ratio
  double get devicePixelRatio => mq.devicePixelRatio;

  /// Responsive Breakpoints (CSS style media queries)
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024;

  // --- Percentage Media Queries directly from context ---
  /// Screen width percentage (e.g. `context.wp(50)` = 50% of screen width)
  double wp(double percent) => (screenWidth * percent) / 100;

  /// Screen height percentage (e.g. `context.hp(30)` = 30% of screen height)
  double hp(double percent) => (screenHeight * percent) / 100;

  /// Percentage aliases
  double percentW(double percent) => wp(percent);
  double percentH(double percent) => hp(percent);

  /// Dynamic pixel scaling directly from context
  double pxW(double px) => ResponsiveSize.isInitialized
      ? ResponsiveSize.setWidth(px)
      : (px * screenWidth / 375);

  double pxH(double px) => ResponsiveSize.isInitialized
      ? ResponsiveSize.setHeight(px)
      : (px * screenHeight / 812);

  double pxSp(double fontSize) => ResponsiveSize.isInitialized
      ? ResponsiveSize.setSp(fontSize)
      : (fontSize * screenWidth / 375);

  /// Select responsive value based on active screen breakpoint
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
