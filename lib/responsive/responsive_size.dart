import 'package:flutter/material.dart';

/// [ResponsiveSize] handles screen scaling, pixel calculation,
/// and percentage-based media query calculations.
class ResponsiveSize {
  static late MediaQueryData _mediaQueryData;
  static double screenWidth = 375;
  static double screenHeight = 812;
  static double defaultDesignWidth = 375;
  static double defaultDesignHeight = 812;
  static Orientation orientation = Orientation.portrait;

  static double _scaleWidth = 1.0;
  static double _scaleHeight = 1.0;
  static double _scaleText = 1.0;

  static bool isInitialized = false;

  /// Initialize ResponsiveSize with BuildContext or MediaQueryData
  static void init(
    BuildContext context, {
    double designWidth = 375,
    double designHeight = 812,
  }) {
    _mediaQueryData = MediaQuery.of(context);
    defaultDesignWidth = designWidth;
    defaultDesignHeight = designHeight;
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;

    _scaleWidth = screenWidth / defaultDesignWidth;
    _scaleHeight = screenHeight / defaultDesignHeight;
    _scaleText = _scaleWidth; // Balanced text scaling factor

    isInitialized = true;
  }

  /// Calculates responsive width based on pixel value
  static double setWidth(double px) {
    if (!isInitialized) return px;
    return px * _scaleWidth;
  }

  /// Calculates responsive height based on pixel value
  static double setHeight(double px) {
    if (!isInitialized) return px;
    return px * _scaleHeight;
  }

  /// Calculates responsive font size (sp - Scalable Pixels)
  static double setSp(double fontSize) {
    if (!isInitialized) return fontSize;
    return fontSize * _scaleText;
  }

  /// Calculates responsive radius (r)
  static double setRadius(double r) {
    if (!isInitialized) return r;
    return r * (_scaleWidth < _scaleHeight ? _scaleWidth : _scaleHeight);
  }

  // ==========================================
  // PERCENTAGE MEDIA QUERY CALCULATIONS (% Screen)
  // ==========================================

  /// Screen Width Percentage (e.g. wp(50) = 50% of screen width)
  static double wp(double percent) {
    return (screenWidth * percent) / 100;
  }

  /// Screen Height Percentage (e.g. hp(30) = 30% of screen height)
  static double hp(double percent) {
    return (screenHeight * percent) / 100;
  }

  /// Font Size Percentage based on Screen Width (e.g. spPercent(4) = 4% of screen width)
  static double spPercent(double percent) {
    return (screenWidth * percent) / 100;
  }

  /// Radius Percentage based on minimum screen dimension
  static double radiusPercent(double percent) {
    final minDimension = screenWidth < screenHeight ? screenWidth : screenHeight;
    return (minDimension * percent) / 100;
  }
}
