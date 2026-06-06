import 'package:flutter/material.dart';

class AppCardTheme {
  static const double borderRadius = 15.0;
  static const double elevation = 0.0;
  static const EdgeInsetsGeometry margins = EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
  static const EdgeInsetsGeometry padding = EdgeInsets.all(16.0);
  static const String fontFamily = 'amiri';

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(borderRadius),
  );
}

extension ColorContrast on Color {
  Color get contrastTextColor {
    return computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
